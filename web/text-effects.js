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
