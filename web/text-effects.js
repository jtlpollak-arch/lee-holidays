// text-effects.js
/**
 * פונקציה שמקבלת טקסט גולמי ומחזירה אותו עם תגיות HTML
 */
// עדכון בתוך text-effects.js - Regex ממוקד למבנה ש-TextStyleHelper מייצר
function processTextEffects(text) {
    // הוספנו דגל 'u' (Unicode) כדי שיתמוך בעברית, 
    // ושינינו את ה-Regex כדי שיהיה גמיש יותר:
    let result = text;
    result = text.replace(/#([a-z])([\s\S]*?)\1#/gu, (match, tag, content) => {
        switch(tag) {
            case 'i': return `<span class="emphasized-rotate">${content}</span>`;
            case 'g': return `<span class="gold-text">${content}</span>`;
            case 'b': return `<span class="bold-large">${content}</span>`;
            case 'u': return `<span class="underline-handwritten">${content}</span>`;
            case 's': return `<span class="wide-spacing">${content}</span>`;
            case 'v': return `<span class="jitter-effect">${content}</span>`;
            case 'f': return `<span class="glow-effect">${content}</span>`;
            case 'w': return `<span class="whisper-text">${content}</span>`;
            case 'h': return `<span class="marker-highlight">${content}</span>`;
            case 'r': return `<span class="pop-up">${content}</span>`;
            default: return match;
        }
    });
    return result;
}

/**
 * פונקציה שמשלבת את הלוגיקה בתוך ה-Typing Effect
 */
function applyTextEffects(text) {
    return processTextEffects(text);
}

/*
function runTypingEffect() {
    const activePage = document.querySelector('.page-content.active');
    if (!activePage) return;

    const textContainer = activePage.querySelector('.text-container');
    if (typingTimeoutId) clearTimeout(typingTimeoutId);

    const rawText = activePage.getAttribute('data-full-text');
    if (!rawText) return;

    const pipeIndex = rawText.indexOf('|');
    const text = rawText.replace('|', '');

    const effects = {
        '#i': 'emphasized-rotate',
        '#g': 'gold-text',
        '#b': 'bold-large',
        '#u': 'underline-handwritten',
        '#s': 'wide-spacing',
        '#v': 'jitter-effect',
        '#f': 'glow-effect',
        '#w': 'whisper-text',
        '#h': 'marker-highlight',
        '#r': 'pop-up'
    };

    let i = 0;
    let output = "";
    let activeEffects = []; 

    function type() {
        if (i < text.length) {
            let consumed = false;

            // 1. בדיקת פתיחת אפקט (למשל #f)
            for (let symbol in effects) {
                if (text.startsWith(symbol, i)) {
                    let className = effects[symbol];
                    let tag = symbol.substring(1); 
                    output += `<span class="${className}">`;
                    activeEffects.push(tag);
                    i += symbol.length; 
                    consumed = true;
                    break;
                }
            }

            // 2. בדיקת סגירת אפקט (למשל f#)
            if (!consumed && activeEffects.length > 0) {
                let lastTag = activeEffects[activeEffects.length - 1];
                if (text.startsWith(lastTag + '#', i)) {
                    output += `</span>`;
                    i += lastTag.length + 1; // מדלגים על האות וה-#
                    activeEffects.pop();
                    consumed = true;
                }
            }

            // 3. הדפסת תו רגיל אם לא נצרך על ידי אפקט
            if (!consumed) {
                let char = text.charAt(i);
                let charToAppend = (char === '\n') ? "<br>" : ((char === ' ') ? "&nbsp;" : char);
                
                // לוגיקת ה-pipe המקורי
                if (i < pipeIndex) {
                    if (i === 0) output += '<span class="client-name">';
                    output += charToAppend;
                    if (i === pipeIndex - 1) output += '</span>';
                } else {
                    output += charToAppend;
                }
                i++;
            }

            textContainer.innerHTML = output + '<span class="caret"></span>';
            typingTimeoutId = setTimeout(type, Math.random() * 50 + 70);
        } else {
            // סיום - העלמת סמן
            const caret = textContainer.querySelector('.caret');
            if (caret) caret.style.display = 'none';

            const hasNextPage = activePage.nextElementSibling !== null;
            if (hasNextPage) {
                autoNavigateTimeout = setTimeout(() => { navigatePage(-1); }, 1000);
            } else {
                const signatureWrapper = activePage.querySelector('.signature-wrapper');
                if (signatureWrapper) signatureWrapper.classList.add('show-signature');
            }
        }
    }

    textContainer.innerHTML = '<span class="caret"></span>';
    type();
}
*/