/**
 * delta-renderer.js
 * מנוע רינדור סופי ומבוטח - עימוד מבוסס אובייקטים שלמים length(word) בלבד
 */

window.MAX_CHARS_PER_LINE = 18;
window.MAX_LINES_PER_PAGE = 4;
window.TYPING_SPEED = 180;

window.globalFlatData = [];
window.globalCharIndex = 0;
window.typingTimeoutId = null;
window.isErasingNow = false;
window.isPausedByClick = false;

const isEmoji = (char) => /\p{Extended_Pictographic}/u.test(char);
const typingCursor = document.createElement('span');
typingCursor.className = 'typing-cursor';
typingCursor.textContent = '•';

// 1. הגדרה גלובלית
let penSound = null;
let isAudioUnlocked = false;

// פונקציית תשתית חדשה - ברז החירום של המנוע (Refactoring)
function stopAndResetEngine() {
    // 1. עצירה מוחלטת של שעון ההקלדה הראשי
    if (window.typingTimeoutId) {
        clearTimeout(window.typingTimeoutId);
        window.typingTimeoutId = null;
    }
    
    // 2. איפוס דגל המחיקה האוטומטי
    window.isErasingNow = false;
    
    // 3. ניקוי מחלקות האנימציה של המחיקה מכל הדפים כדי שלא יישארו קפואים
    document.querySelectorAll('.page-content .text-container').forEach(container => {
        container.classList.remove('erase-active');
    });
}

// פונקציית הגשר המוזמנת מהדף הראשי
function runTypingEffect(delta) {
    if (!delta) {
        return;
    }
    paginateTextAndRender(delta);
}






/**********************************************************************************/

// 1. פונקציית פירוק ה-Delta לטוקנים
function parseDeltaToTokens(data) {
    let rawTokens = [];
    data.forEach(item => {
        const text = item.insert || "";
        const attrs = item.attributes || {};
        const classes = attrs.effect ? attrs.effect.split(',').map(c => `effect-${c}`) : [];
        const parts = text.split(/(\s+|\n)/);
        parts.forEach(part => {
            if (part !== "") {
                rawTokens.push({ text: part, classes: classes });
            }
        });
    });
    return rawTokens;
}

// 2. בניית ה-Layout
function buildPagesLayout(rawTokens) {
    let pages = [];
    let currentPage = [];
    let currentLine = [];
    let currentLineChars = 0;

    rawTokens.forEach(token => {
        if (token.text === '\n') {
            if (currentLine.length > 0) currentPage.push(currentLine);
            currentLine = [];
            currentLineChars = 0;
            return;
        }

        const isSpace = token.text.trim() === '';
        if (isSpace) {
            if (currentLineChars === 0 || currentLineChars + 1 > window.MAX_CHARS_PER_LINE) return;
            currentLine.push(token);
            currentLineChars += 1;
        } else {
            let wordLen = Array.from(token.text).length;
            if (wordLen > window.MAX_CHARS_PER_LINE) {
                token.text = Array.from(token.text).slice(0, window.MAX_CHARS_PER_LINE).join('') + "...";
                wordLen = window.MAX_CHARS_PER_LINE;
            }
            if (currentLineChars + wordLen > window.MAX_CHARS_PER_LINE) {
                if (currentLine.length > 0 && currentLine[currentLine.length - 1].text.trim() === '') currentLine.pop();
                currentPage.push(currentLine);
                currentLine = [];
                currentLineChars = 0;
            }
            currentLine.push(token);
            currentLineChars += wordLen;
        }

        if (currentPage.length >= window.MAX_LINES_PER_PAGE) {
            pages.push(currentPage);
            currentPage = [];
        }
    });

    if (currentLine.length > 0) {
        if (currentLine[currentLine.length - 1].text.trim() === '') currentLine.pop();
        if (currentLine.length > 0) currentPage.push(currentLine);
    }
    if (currentPage.length > 0) pages.push(currentPage);
    return pages;
}

// 3. הפיכת ה-Layout לתווים שטוחים עם זיהוי אימוג'י
function flattenLayoutToChars(pages) {
    let flatResult = [];

    pages.forEach((page, pIdx) => {
        page.forEach(line => {
            line.forEach(t => {
                Array.from(t.text).forEach(char => {
                    let finalClasses = [...t.classes];
                    
                    if (isEmoji(char)) {
                        // אנחנו כבר לא מוחקים את קלאס האפקט, כי ה-CSS שלנו יודע
                        // לטפל בהפרדה באמצעות הקלאס החדש שאנחנו מוסיפים כאן
                        finalClasses.push('is-emoji');
                    }

                    flatResult.push({ char: char, classes: finalClasses, pageIndex: pIdx });
                });
            });
            flatResult.push({ char: '\n', classes: [], pageIndex: pIdx });
        });
    });
    return flatResult;
}

// 4. פונקציה ראשית מנהלת
// הפונקציה הראשית המנהלת את התהליך
// 4. פונקציה ראשית מנהלת
function flattenDelta(delta) {
    // שומר סף חכם: אם המבנה כבר שטוח (מכיל char או pageIndex), אין מה לנתח שוב!
    // זה מונע את השגיאה שקרתה בהרצה השנייה של פונקציית הרינדור.
    if (Array.isArray(delta) && delta.length > 0 && (delta[0].char !== undefined || delta[0].pageIndex !== undefined)) {
        return delta;
    }

    // פענוח הנתונים (בדיקה שזה JSON או מערך)
    let data;
    try { 
        data = typeof delta === 'string' ? JSON.parse(delta) : delta; 
    } catch (e) { 
        console.error("--> [DEBUG] JSON parse error:", e);
        return []; 
    }

    if (!data || !Array.isArray(data)) {
        console.error("--> [DEBUG] data is not a valid array");
        return [];
    }

    // הרצה מסודרת של ה-Pipeline
    const rawTokens = parseDeltaToTokens(data);
    
    const pages = buildPagesLayout(rawTokens);
    
    const flatResult = flattenLayoutToChars(pages);
    
    return flatResult;
}

/********************************************************************************************/





















// 4. בניית העמודים ב-DOM והכנת התשתית הויזואלית
function paginateTextAndRender(delta) {
    const flatData = flattenDelta(delta);
    if (!flatData || flatData.length === 0) {
        console.error("<--paginateTextAndRender--> שגיאה: מערך התווים המעובד ריק!");
        return;
    }

    const container = document.getElementById('pagesContainer');
    if (!container) {
        console.error("<--paginateTextAndRender--> שגיאה קריטית: לא נמצא pagesContainer ב-DOM");
        return;
    }

    let pen = container.querySelector('.writing-pen');
    if (!pen) {
        pen = document.createElement('div');
        pen.className = 'writing-pen';
        container.appendChild(pen);
    }
    
    container.innerHTML = '';
    const maxPage = Math.max(...flatData.map(d => d.pageIndex), 0);
    
    for (let i = 0; i <= maxPage; i++) {
        const pageDiv = document.createElement('div');
        pageDiv.className = `page-content ${i === 0 ? 'active' : ''}`;
        pageDiv.id = `page-${i}`;
        pageDiv.innerHTML = '<div class="text-container" style="white-space: pre-wrap; direction: rtl; text-align: right;"></div>';
        
        // אם הגענו לעמוד האחרון בסדרה, נשכפל את החתימה ונכניס אותה
        if (i === maxPage) {
            injectSignatureWithEffect(pageDiv);
        }
        
        container.appendChild(pageDiv);
    }

    const dotsContainer = document.getElementById('pageDots');
    if (dotsContainer) {
        dotsContainer.innerHTML = ''; // ניקוי נקודות ישנות מהמסך
        for (let i = 0; i <= maxPage; i++) {
            const dot = document.createElement('div');
            dot.className = `dot ${i === 0 ? 'active' : ''}`;
            dot.id = `dot-idx-${i}`;
            // הצמדת אירוע הלחיצה לפונקציה החדשה שעדכנו ב-index.html
            dot.setAttribute('onclick', `switchToTargetPage(${i});`);
            dotsContainer.appendChild(dot);
        }
    }

    window.globalFlatData = flatData;
    window.globalCharIndex = 0;
    
    if (window.typingTimeoutId) {
        clearTimeout(window.typingTimeoutId);
    }
    
    typeNextChar();
}



function injectSignatureWithEffect(pageDiv) {
    const originalSignature = document.querySelector('.lee-signature');
    if (originalSignature) {
        const signatureDiv = document.createElement('span');
        signatureDiv.className = 'signature-wrapper';
        
        const sigSvg = originalSignature.cloneNode(true);
        
        // --- ניקוי מאפיינים שעלולים להסתיר את החתימה ---
        sigSvg.style.display = 'block'; 
        sigSvg.style.position = 'static';
        sigSvg.style.visibility = 'visible';
        sigSvg.style.opacity = '1';
        sigSvg.style.width = '40px'; 
        sigSvg.style.height = '40px';
        signatureDiv.style.position = 'relative';
        signatureDiv.style.top = '10px';
        // ----------------------------------------------
        
        signatureDiv.appendChild(sigSvg);
        pageDiv.appendChild(signatureDiv);
    }
}

async function highlightCornersAndDimPage(pageDiv) {

    const signatureWrapper = pageDiv.querySelector('.signature-wrapper');
    if (!signatureWrapper) {
        // אם אין חתימה, פשוט נבצע את הניקוי הרגיל
        pageDiv.classList.add('dim-page');
        if (typeof drawRoadmap === 'function') drawRoadmap();
        return;
    }

    // חישוב מיקום אבסולוטי עבור ה-Canvas הצף
    const rect = signatureWrapper.getBoundingClientRect();
    const startX = rect.left + (rect.width / 2);
    const startY = rect.top + (rect.height / 2);

    // הפעלת האנימציה (ללא נגיעה ב-DOM הפנימי של המעטפה)
    await drawSignatureGoldDots(startX, startY);

    // ניקוי המסך והמשך כרגיל
    pageDiv.classList.add('dim-page'); 
    const cornerElements = document.querySelectorAll('.lee-key-container-svg, .lee-course-svg, .lee-safe-home-svg, .logo-wrapper, .lee-handshake-svg');
    cornerElements.forEach(el => el.classList.add('visible-corner'));

    if (typeof drawRoadmap === 'function') {
        setTimeout(() => {
            drawRoadmap();
        }, 300);
    }
}


/**
 * אנימציית "קשת אקרובטית לימין" - עם שובל זהוב דועך
 */
function drawSignatureGoldDots(startX, startY) {
    return new Promise((resolve) => {
        const canvas = document.createElement('canvas');
        canvas.style.position = 'absolute';
        canvas.style.top = '0';
        canvas.style.left = '0';
        canvas.style.width = document.documentElement.scrollWidth + 'px';
        canvas.style.height = document.documentElement.scrollHeight + 'px';
        canvas.style.zIndex = '99999';
        canvas.style.pointerEvents = 'none';
        document.body.appendChild(canvas);

        const ctx = canvas.getContext('2d');
        canvas.width = document.documentElement.scrollWidth;
        canvas.height = document.documentElement.scrollHeight;

        // נקודת יעד (פינה שמאלית תחתונה)
        const endX = window.innerWidth * 0.15 + window.scrollX;
        const endY = (window.innerHeight * 0.85) + window.scrollY;

        // נקודות שליטה ל-Cubic Bézier (למסלול אקרובטי):
        // cp1: מושך את היציאה אחורה ולמעלה (שעה 10)
        const cp1X = startX - (window.innerWidth * 0.3);
        const cp1Y = startY - (window.innerHeight * 0.3);
        
        // cp2: מושך את הקשת רחבה ימינה ולמעלה (שעה 2)
        const cp2X = startX + (window.innerWidth * 0.4);
        const cp2Y = startY - (window.innerHeight * 0.4);

        let t = 0;
        const speed = 0.005; // איטי ואלגנטי יותר
        const trail = [];
        const spacing = 12; 
        let lastDrawnX = startX;
        let lastDrawnY = startY;

        function animate() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            t += speed;
            
            // פונקציית Easing מואצת
            const easeT = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
            
            // נוסחת Cubic Bézier עם 2 נקודות שליטה
            const x = Math.pow(1 - easeT, 3) * startX + 
                      3 * Math.pow(1 - easeT, 2) * easeT * cp1X + 
                      3 * (1 - easeT) * Math.pow(easeT, 2) * cp2X + 
                      Math.pow(easeT, 3) * endX;
            
            const y = Math.pow(1 - easeT, 3) * startY + 
                      3 * Math.pow(1 - easeT, 2) * easeT * cp1Y + 
                      3 * (1 - easeT) * Math.pow(easeT, 2) * cp2Y + 
                      Math.pow(easeT, 3) * endY;

            // ציור מבוסס מרחק למניעת דחיסות בסלולר
            const dist = Math.hypot(x - lastDrawnX, y - lastDrawnY);
            if (dist >= spacing) {
                trail.push({ x: x, y: y, alpha: 1 });
                lastDrawnX = x;
                lastDrawnY = y;
            }

            // שובל דועך
            for (let i = 0; i < trail.length; i++) {
                const dot = trail[i];
                dot.alpha -= 0.012; 
                if (dot.alpha > 0) {
                    ctx.fillStyle = `rgba(184, 134, 11, ${dot.alpha})`;
                    ctx.beginPath();
                    ctx.arc(dot.x, dot.y, 3, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            if (trail[0] && trail[0].alpha <= 0) trail.shift();

            // ציור ראש השביט
            if (t < 1) {
                ctx.fillStyle = 'rgba(255, 215, 0, 1)';
                ctx.shadowColor = 'rgba(255, 215, 0, 0.8)';
                ctx.shadowBlur = 12;
                ctx.beginPath();
                ctx.arc(x, y, 4, 0, Math.PI * 2);
                ctx.fill();
                ctx.shadowBlur = 0;
                requestAnimationFrame(animate);
            } else {
                setTimeout(() => {
                    canvas.remove();
                    resolve();
                }, 400);
            }
        }
        animate();
    });
}


/**********************************************************
 * 
 * typeNextChar()
 * 
 ***********************************************************/
function handleTypingComplete() {
    const activePage = document.querySelector('.page-content.active');
    if (activePage) {
        const signatureWrapper = activePage.querySelector('.signature-wrapper');
        
        if (signatureWrapper) {
            const existingHeart = signatureWrapper.querySelector('.signature-heart-wrapper');
            if (existingHeart) {
                existingHeart.remove();
            }

            // 1. הפעלת ה-Transition של החתימה הקיימת
            signatureWrapper.classList.add('show-signature');
            
            // 2. יצירת הלב בצורה דינמית ונקייה
            // אנחנו לא מוסיפים div חדש כדי לא לשבור את הפריסה, 
            // פשוט מוסיפים את ה-SVG ישירות ל-wrapper
            const heartHtml = `
                <div class="signature-heart-wrapper" style="display: inline-flex; align-items: center;">
                    <svg viewBox="0 0 32 32" style="width: 20px; height: 20px; fill: #B8860B;">
                        <!-- הלב הראשי -->
                        <path d="M16 28.5l-1.3-1.2C6.8 20.2 2 15.9 2 10.5 2 6.1 5.3 2.8 9.5 2.8c2.4 0 4.7 1.1 6.5 2.8 1.8-1.7 4.1-2.8 6.5-2.8C26.7 2.8 30 6.1 30 10.5c0 5.4-4.8 9.7-12.7 16.8L16 28.5z"/>
                        <!-- בית חתוך בפנים (בצבע הרקע - לבן) -->
                        <path d="M16 9l-6 5.5v7.5h4v-4h4v4h4v-7.5L16 9z" fill="#FFFFFF"/>
                    </svg>
                </div>
            `;

            
            // הוספת הלב ל-wrapper
            signatureWrapper.insertAdjacentHTML('beforeend', heartHtml);

            if (typingCursor.parentNode) {
                typingCursor.parentNode.removeChild(typingCursor);
            }
            
            // 3. דיליי של 2.5 שניות ל-WOW הסופי
            setTimeout(() => {
                // מפעיל את העמעום והדגשת הפינות
                highlightCornersAndDimPage(activePage);
            }, 500);
        }
    }
}

function renderNextToken(item, container) {
    if (item.char === '\n') {
        container.appendChild(document.createElement('br'));
        return;
    }

    const isTargetEmoji = isEmoji(item.char);
    const effectClasses = (item.classes || []).map(c => c.trim()).filter(c => c.length > 0);
    
    // חישוב זמן הייבוש הדינמי
    const currentSpeed = window.TYPING_SPEED || 120;
    const dryDelay = currentSpeed * 0.8; // זמן מעט ארוך יותר כדי שהעין תספיק לראות את האפקט

    let targetElement = null; // זה יהיה האלמנט שעליו נלביש את הדיו

    if (effectClasses.length > 0) {
        let outermostSpan = null;
        let currentInnerSpan = null;

        for (let i = 0; i < effectClasses.length; i++) {
            const newSpan = document.createElement('span');
            newSpan.classList.add(effectClasses[i]);
            
            if (isTargetEmoji) newSpan.classList.add('is-emoji');

            if (i === 0) outermostSpan = newSpan;
            else currentInnerSpan.appendChild(newSpan);
            
            currentInnerSpan = newSpan;
        }

        currentInnerSpan.textContent = item.char;
        targetElement = outermostSpan;
        container.appendChild(outermostSpan);
    } else {
        const span = document.createElement('span');
        span.textContent = item.char;
        if (isTargetEmoji) span.classList.add('is-emoji');
        
        targetElement = span;
        container.appendChild(span);
    }

    // הלבשת הדיו הרטוב על האלמנט הסופי
    targetElement.classList.add('active-typing');

    // ייבוש הדרגתי: הסרת הקלאס לאחר הזמן המוגדר
    setTimeout(() => {
        if (targetElement && targetElement.parentNode) {
            targetElement.classList.remove('active-typing');
        }
    }, dryDelay);
}


function handlePageTransition(item, pageDiv) {
    if (window.isPausedByClick) {
        return true; // חסום המשך
    }
    
    if (window.isErasingNow) {
        return true; // חסום המשך
    }

    const oldActivePage = document.querySelector('.page-content.active');
    
    if (oldActivePage) {
        const oldContainer = oldActivePage.querySelector('.text-container');
        if (oldContainer) {
            window.isErasingNow = true;
            oldContainer.classList.add('erase-active');
            
            window.typingTimeoutId = setTimeout(() => {
                oldContainer.classList.remove('erase-active');
                
                // מעבר פיזי לעמוד החדש
                document.querySelectorAll('.page-content').forEach(p => p.classList.remove('active'));
                pageDiv.classList.add('active');
                
                // עדכון נקודות הניווט
                const dots = document.querySelectorAll('.dot');
                if (dots.length > 0) {
                    document.querySelectorAll('.dot').forEach(d => d.classList.remove('active'));
                    const currentDot = document.getElementById(`dot-idx-${item.pageIndex}`);
                    if (currentDot) currentDot.classList.add('active');
                }
                
                window.isErasingNow = false;
                
                // שחרור המנוע להמשך הקלדה בעמוד החדש
                window.globalCharIndex++;
                window.typingTimeoutId = setTimeout(typeNextChar, window.TYPING_SPEED);
            }, 2100);
            
            return true; // מעבר מנוהל אסינכרונית, חסום ריצה רגילה
        }
    }
    
    // הגנה והפעלה לעמוד הראשון ללא טיימר
    document.querySelectorAll('.page-content').forEach(p => p.classList.remove('active'));
    pageDiv.classList.add('active');
    const dots = document.querySelectorAll('.dot');
    if (dots.length > 0) {
        document.querySelectorAll('.dot').forEach(d => d.classList.remove('active'));
        const currentDot = document.getElementById(`dot-idx-${item.pageIndex}`);
        if (currentDot) currentDot.classList.add('active');
    }
    
    return false; // אל תחסום ריצה רגילה
}

function typeNextChar() {
    // 1. בדיקת סיום חלוטין של המערך
    if (window.globalCharIndex >= window.globalFlatData.length) {
        handleTypingComplete();
        return;
    }

    const item = window.globalFlatData[window.globalCharIndex];
    const pageDiv = document.getElementById(`page-${item.pageIndex}`);
    
    // 2. בדיקת קיום הדף
    if (!pageDiv) {
        window.globalCharIndex++;
        typeNextChar();
        return;
    }

    const container = pageDiv.querySelector('.text-container');

    // 3. רינדור התו הנוכחי לתוך הקונטיינר (מנוע המטריושקה)
    renderNextToken(item, container);

    container.appendChild(typingCursor);

    // 4. ניהול מעברי עמודים במידה והעמוד משתנה
    if (!pageDiv.classList.contains('active')) {
        const isHandled = handlePageTransition(item, pageDiv);
        if (isHandled) return; // עוצרים כאן אם המעבר מנוהל בטיימר של המחיקה
    }

    // 5. קידום לתו הבא במצב רגיל
    window.globalCharIndex++;
    window.typingTimeoutId = setTimeout(typeNextChar, window.TYPING_SPEED);
}