function launchContextualConfetti() {
    console.log("[CONF-DEBUG] -> פונקציית הקונפטי התחילה.");
    const container = document.getElementById('confetti-container');
    if (!container) return;

    // וודא קונטיינר פרוס על כל המסך
    container.style.position = 'fixed';
    container.style.top = '0px';
    container.style.left = '0px';
    container.style.width = '100vw';
    container.style.height = '100vh';
    container.style.zIndex = '9999999';
    container.style.overflow = 'visible';
    container.style.pointerEvents = 'none';
    container.innerHTML = ''; 

    const emojiPool = ['🏠', '🏡', '🔑', '🗝️', '💖', '🪴', '✨', '💎', '🥂', '🌟', '🌸', '🌷', '🦋', '🧡', '🌞'];
    const numberOfEmojis = 35; 
    
    // נקודות ייחוס למסך
    const w = window.innerWidth;
    const h = window.innerHeight;

    for (let i = 0; i < numberOfEmojis; i++) {
        const emojiItem = document.createElement('div');
        emojiItem.classList.add('wow-confetti-item');
        emojiItem.innerText = Math.random() < 0.1 ? '🔑' : emojiPool[Math.floor(Math.random() * emojiPool.length)];

        // חישוב מיקום אקראי על כל המסך בפיקסלים
        const startX = Math.random() * w;
        const startY = -100; // מעט מעל המסך
        const endX = startX + (Math.random() - 0.5) * (w * 0.5);
        const endY = h + 100; // מתחת למסך
        
        const rotZ = Math.random() * 720;
        const scale = Math.random() * 0.6 + 0.6;
        const duration = 6000 + Math.random() * 4000;
        const delay = i * 200; // דירוג קבוע (מזרקה)

        // הזרקת סגנון ישירה - זה עוקף את בעיית הפינה
        Object.assign(emojiItem.style, {
            position: 'fixed',
            fontSize: (w < 768 ? '1.6rem' : '2.5rem'),
            zIndex: '999999',
            pointerEvents: 'none',
            left: '0px',
            top: '0px',
            opacity: '0'
        });

        container.appendChild(emojiItem);

        console.log(`[CONF-DEBUG] -> אימוג'י ${i} נוצר במיקום ${startX}, ${startY}`);

        emojiItem.animate([
            { transform: `translate(${startX}px, ${startY}px) scale(${scale}) rotate(0deg)`, opacity: 0 },
            { opacity: 0.8, offset: 0.1 },
            { opacity: 0.8, offset: 0.85 },
            { transform: `translate(${endX}px, ${endY}px) scale(${scale}) rotate(${rotZ}deg)`, opacity: 0 }
        ], {
            duration: duration,
            delay: delay,
            fill: 'forwards',
            easing: 'linear'
        });

        setTimeout(() => { 
            if (emojiItem.parentNode) emojiItem.remove(); 
        }, duration + delay + 500);
    }
}