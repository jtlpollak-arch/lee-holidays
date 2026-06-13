// audio-player.js

/**
 * פונקציה ליצירת והפעלת נגן ה"נגיעה קולית" הצף
 * @param {string} voiceUrl - הלינק לקובץ האודיו מ-Firebase Storage
 */
function initAudioPlayer(voiceUrl) {
    if (!voiceUrl || voiceUrl.trim() === "") return;

    // 1. יצירת אלמנט האודיו הנסתר
    const audio = new Audio(voiceUrl);

    // 2. יצירת קונטיינר הכפתור
    const container = document.createElement('div');
    container.className = 'audio-fab-container';
    container.innerHTML = `
        <span class="audio-icon">▶</span>
        <span class="audio-label">נגיעה קולית</span>
    `;
    
    // הזרקה לתוך ה-Body
    document.body.appendChild(container);

    // 3. אנימציית כיווץ אוטומטית אחרי 4 שניות
    setTimeout(() => {
        container.classList.add('shrunk');
    }, 4000);

    // 4. לוגיקת לחיצה: ניגון/השהיה
    container.addEventListener('click', () => {
        const icon = container.querySelector('.audio-icon');
        
        if (audio.paused) {
            audio.play();
            icon.innerText = '⏸';
        } else {
            audio.pause();
            icon.innerText = '▶';
        }
    });

    // 5. האזנה לסיום הניגון - מחזיר את הכפתור למצב Play
    audio.addEventListener('ended', () => {
        const icon = container.querySelector('.audio-icon');
        icon.innerText = '▶';
        audio.currentTime = 0; // החזרה להתחלה למקרה שהמשתמש ילחץ שוב
    });
}