/**
 * delta-renderer.js
 * מנוע רינדור סופי ומבוטח - עימוד מבוסס אובייקטים שלמים length(word) בלבד
 */

window.MAX_CHARS_PER_LINE = 18;
window.MAX_LINES_PER_PAGE = 4;
window.TYPING_SPEED = 120;

window.globalFlatData = [];
window.globalCharIndex = 0;
window.typingTimeoutId = null;
window.isErasingNow = false;

// פונקציית הגשר המוזמנת מהדף הראשי
function runTypingEffect(delta) {
    console.log("<--runTypingEffect--> גשר מופעל");
    if (!delta) {
        return;
    }
    paginateTextAndRender(delta);
}

// 1. Parser חכם - הופך את ה-Delta לרשימה שטוחה של Tokens (אובייקטים שלמים)
function flattenDelta(delta) {
    console.log("<--flattenDelta--> תחילת עיבוד והכנת Tokens");
    
    // שומר סף: אם הנתונים כבר עובדו בעבר למבנה תווים סופי, נחזיר אותם מיד
    if (Array.isArray(delta) && delta.length > 0 && delta[0].pageIndex !== undefined) {
        console.log("<--flattenDelta--> נתונים כבר מעובדים, מחזיר אותם ישירות");
        return delta;
    }

    let data;
    try {
        data = typeof delta === 'string' ? JSON.parse(delta) : delta;
    } catch (e) {
        console.error("<--flattenDelta--> שגיאה בפענוח ה-JSON:", e);
        return [];
    }

    if (!data || !Array.isArray(data)) {
        console.error("<--flattenDelta--> שגיאה: הנתונים אינם מערך תקין");
        return [];
    }

    let rawTokens = [];

    // פירוק ה-Delta למילים ורווחים תוך העתקת ה-Attributes לכל אלמנט בנפרד
    data.forEach(item => {
        const text = item.insert || "";
        const attrs = item.attributes || {};
        const classes = attrs.effect ? attrs.effect.split(',').map(c => `effect-${c}`) : [];
        
        // פירוק לפי רווחים וירידות שורה, תוך שמירה עליהם כאלמנטים עצמאיים
        const parts = text.split(/(\s+|\n)/);
        parts.forEach(part => {
            if (part !== "") {
                rawTokens.push({ text: part, classes: classes });
            }
        });
    });

    console.log("<--flattenDelta--> פירוק ל-Tokens הסתיים. כמות איברים גולמית:", rawTokens.length);

    // 2. בניית ה-Layout הלוגי - חישוב שורות ועמודים על בסיס אובייקטים שלמים בלבד length(word)
    let pages = [];
    let currentPage = [];
    let currentLine = [];
    let currentLineChars = 0;

    rawTokens.forEach(token => {
        // טיפול בירידת שורה מפורשת בטקסט
        if (token.text === '\n') {
            if (currentLine.length > 0) {
                currentPage.push(currentLine);
            }
            currentLine = [];
            currentLineChars = 0;
            return;
        }

        // בדיקה האם מדובר ברווח
        const isSpace = token.text.trim() === '';

        if (isSpace) {
            // חוק: אל תדפיס רווחים בתחילת שורה
            if (currentLineChars === 0) {
                return; 
            }
            // חוק: אל תדפיס רווחים בסוף שורה (אם הרווח מביא אותנו בדיוק לקצה, נתעלם ממנו)
            if (currentLineChars + 1 > window.MAX_CHARS_PER_LINE) {
                return;
            }
            
            currentLine.push(token);
            currentLineChars += 1;
        } else {
            // חישוב אורך המילה השלמה (אמוג'י נספר כתו אחד במערך תווים של ES6)
            let wordLen = Array.from(token.text).length;
            
            if (wordLen > window.MAX_CHARS_PER_LINE) {
                token.text = Array.from(token.text).slice(0, MAX_CHARS_PER_LINE).join('') + "...";
                wordLen = MAX_CHARS_PER_LINE;
            }

            // החלטה קריטית ברמת האובייקט השלם: האם המילה נכנסת בפוזיציה הנוכחית?
            if (currentLineChars + wordLen > window.MAX_CHARS_PER_LINE) {
                // מניעת רווחים מיותרים בסוף השורה שנסגרת עכשיו
                if (currentLine.length > 0 && currentLine[currentLine.length - 1].text.trim() === '') {
                    currentLine.pop();
                }
                
                currentPage.push(currentLine);
                currentLine = [];
                currentLineChars = 0;
            }

            currentLine.push(token);
            currentLineChars += wordLen;
        }

        // ניהול ומעבר עמודים (MAX_LINES_PER_PAGE)
        if (currentPage.length >= window.MAX_LINES_PER_PAGE) {
            pages.push(currentPage);
            currentPage = [];
        }
    });

    // סגירת שאריות שורות ועמודים
    if (currentLine.length > 0) {
        if (currentLine[currentLine.length - 1].text.trim() === '') currentLine.pop();
        if (currentLine.length > 0) currentPage.push(currentLine);
    }
    if (currentPage.length > 0) {
        pages.push(currentPage);
    }

    console.log("<--flattenDelta--> חישוב ה-Layout הסתיים. כמות עמודים לוגיים:", pages.length);

    // 3. הפיכת מבנה ה-Layout המוגמר למערך תווים שטוח ואטומי המשמש אך ורק את טיימר ההקלדה
    let flatResult = [];
    pages.forEach((page, pIdx) => {
        page.forEach(line => {
            line.forEach(t => {
                Array.from(t.text).forEach(char => {
                    flatResult.push({ char: char, classes: t.classes, pageIndex: pIdx });
                });
            });
            // בסוף כל שורה לוגית מוגדרת מראש, נזריק ירידת שורה קשיחה ל-HTML
            flatResult.push({ char: '\n', classes: [], pageIndex: pIdx });
        });
    });

    console.log("<--flattenDelta--> הכנת מערך התווים הסתיימה. סך הכל תווים להקלדה:", flatResult.length);
    return flatResult;
}

// 4. בניית העמודים ב-DOM והכנת התשתית הויזואלית
function paginateTextAndRender(delta) {
    console.log("<--paginateTextAndRender--> פונקציית הרינדור הראשית התחילה");
    
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
    
    container.innerHTML = '';
    const maxPage = Math.max(...flatData.map(d => d.pageIndex), 0);
    console.log("<--paginateTextAndRender--> מכין ב-DOM עמודים פיזיים ריקים:", maxPage + 1);
    
    for (let i = 0; i <= maxPage; i++) {
        const pageDiv = document.createElement('div');
        pageDiv.className = `page-content ${i === 0 ? 'active' : ''}`;
        pageDiv.id = `page-${i}`;
        pageDiv.innerHTML = '<div class="text-container" style="white-space: pre-wrap; direction: rtl; text-align: right;"></div>';
        
        // אם הגענו לעמוד האחרון בסדרה, נשכפל את החתימה ונכניס אותה
        if (i === maxPage) {
            const originalSignature = document.querySelector('.lee-signature');
            if (originalSignature) {
                const signatureDiv = document.createElement('div');
                signatureDiv.className = 'signature-wrapper';
                
                // שכפול ה-SVG המקורי על כל תכונותיו ומבנה הקווים הפנימיים שלו
                const sigSvg = originalSignature.cloneNode(true);
                signatureDiv.appendChild(sigSvg);
                
                // הזרקה ישירה לתוך העמוד, מחוץ ומסביב ל-text-container
                pageDiv.appendChild(signatureDiv);
                console.log("<--paginateTextAndRender--> חתימת ה-SVG שוכפלה בהצלחה לעמוד האחרון (" + i + ")");
            }
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
        console.log("<--paginateTextAndRender--> נקודות הניווט נבנו בהצלחה ב-DOM");
    }

    window.globalFlatData = flatData;
    window.globalCharIndex = 0;
    
    if (window.typingTimeoutId) {
        clearTimeout(window.typingTimeoutId);
    }
    
    console.log("<--paginateTextAndRender--> קורא לתו הראשון להקלדה");
    typeNextChar();
}

// 5. מנוע ההקלדה הויזואלי (פועל על המיקומים והעמודים המוגמרים שחושבו מראש)
function typeNextChar() {
    if (window.globalCharIndex >= window.globalFlatData.length) {
        console.log("<--typeNextChar--> תהליך ההקלדה הסתיים בהצלחה לכל העמודים");
        
        // מוצאים את העמוד הפעיל הנוכחי (שהוא העמוד האחרון שבו הסתיימה ההקלדה)
        const activePage = document.querySelector('.page-content.active');
        if (activePage) {
            // מחפשים בתוכו את מיכל החתימה שהזרקנו מראש
            const signatureWrapper = activePage.querySelector('.signature-wrapper');
            if (signatureWrapper) {
                // מדליקים את הקלאס שמפעיל את ה-CSS ואת האנימציה של הזהב
                signatureWrapper.classList.add('show-signature');
                console.log("<--typeNextChar--> ההקלדה הסתיימה, החתימה הודלקה בהצלחה!");
            }
        }
        return;
    }

    const item = window.globalFlatData[window.globalCharIndex];
    const pageDiv = document.getElementById(`page-${item.pageIndex}`);
    
    if (!pageDiv) {
        window.globalCharIndex++;
        typeNextChar();
        return;
    }

    const container = pageDiv.querySelector('.text-container');

    if (item.char === '\n') {
        container.appendChild(document.createElement('br'));
    } else {
        const span = document.createElement('span');
        span.textContent = item.char;
        item.classes.forEach(c => span.classList.add(c));
        container.appendChild(span);
    }

    // ניהול החלפת העמוד הויזואלי הפעיל עם אפקט מחיקה אלקטרונית עדינה
    // ניהול החלפת העמוד הויזואלי הפעיל עם אפקט מחיקה אלקטרונית עדינה ושומר סף
    if (!pageDiv.classList.contains('active')) {
        
        // חסימת כפל הרצות: אם המנוע כבר נמצא בתהליך מחיקה, עצור מיד!
        if (window.isErasingNow) {
            return;
        }

        const oldActivePage = document.querySelector('.page-content.active');
        
        if (oldActivePage) {
            const oldContainer = oldActivePage.querySelector('.text-container');
            if (oldContainer) {
                console.log("<--typeNextChar--> מפעיל מחיקה אלקטרונית עדינה על עמוד ישן");
                
                // נועלים את השער כדי למנוע מטיימרים מקבילים להיכנס לכאן
                window.isErasingNow = true;
                
                // 1. מדליקים את אפקט הניגוב ב-CSS
                oldContainer.classList.add('erase-active');
                
                // 2. מקפיאים את מנוע ההקלדה למשך 900 מילישניות כדי לתת לאפקט להסתיים בחלקות
                window.typingTimeoutId = setTimeout(() => {
                    // מנקים את אפקט המחיקה מהקונטיינר הישן
                    oldContainer.classList.remove('erase-active');
                    
                    // 3. מבצעים את המעבר הפיזי לעמוד החדש
                    document.querySelectorAll('.page-content').forEach(p => p.classList.remove('active'));
                    pageDiv.classList.add('active');
                    
                    // עדכון נקודות הניווט (Dots) בהתאמה לעמוד החדש
                    const dots = document.querySelectorAll('.dot');
                    if (dots.length > 0) {
                        document.querySelectorAll('.dot').forEach(d => d.classList.remove('active'));
                        const currentDot = document.getElementById(`dot-idx-${item.pageIndex}`);
                        if (currentDot) currentDot.classList.add('active');
                    }
                    
                    // פותחים את השער בחזרה לקראת מעבר העמוד הבא בעתיד
                    window.isErasingNow = false;
                    
                    // 4. משחררים את המנוע להמשיך להקליד את התו הבא על דף נקי
                    window.globalCharIndex++;
                    window.typingTimeoutId = setTimeout(typeNextChar, window.TYPING_SPEED);
                }, 2200);
                
                return; // עוצרים את הלולאה הנוכחית בזמן ההמתנה
            }
        }
        
        // הגנה לעמוד הראשון בהתחלה
        document.querySelectorAll('.page-content').forEach(p => p.classList.remove('active'));
        pageDiv.classList.add('active');
        const dots = document.querySelectorAll('.dot');
        if (dots.length > 0) {
            document.querySelectorAll('.dot').forEach(d => d.classList.remove('active'));
            const currentDot = document.getElementById(`dot-idx-${item.pageIndex}`);
            if (currentDot) currentDot.classList.add('active');
        }
    }

    window.globalCharIndex++;
    window.typingTimeoutId = setTimeout(typeNextChar, window.TYPING_SPEED);
}