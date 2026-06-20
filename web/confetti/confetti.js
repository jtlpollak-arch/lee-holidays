function launchContextualConfetti() {
    const container = document.getElementById('confetti-container');
    if (!container) return;

    container.innerHTML = ''; 
    const emojiPool = [
        '🏠', '🌱', '🔑', '🗝️', '💖', 
        '🌷', '🌻', '🌹', '🪻', '🪷',
        '👑', '🌺', '🌻', '🍃', '🏡',
        '💐', '🪄', '🧿', '🔮', '💝'
    ];
    const w = window.innerWidth;
    const h = window.innerHeight;
    let emojiIndex = 0;
    let goLeft = true;

    for (let i = 0; i < 20; i++) {
        const emojiItem = document.createElement('div');
        emojiItem.classList.add('wow-confetti-item');

        if(emojiIndex == emojiPool.length) {emojiIndex = 0;}
        emojiItem.innerText = emojiPool[emojiIndex++ % emojiPool.length];

        // --- לוגיקת הדחייה המרכזית ---
        const isLeft = goLeft;
        goLeft = !goLeft;

        // מתחילים מהמרכז התחתון
        const startX = w / 2;
        const startY = h + 50;
        
        // יעד: אם שמאל - טווח שלילי, אם ימין - טווח חיובי. 
        // 0.2 עד 0.6 מבטיח שהם נשארים בטווח ה-45 מעלות מהאמצע
        const minDrift = 0.5; 
        const randomRange = 0.0; // טווח של 15% בלבד

        const drift = (minDrift + Math.random() * randomRange) * (isLeft ? -w : w);
        let endX = startX + drift;

        // --- תיקון הסימטריה (קיזוז הקיר הימני) ---
        if (!isLeft) {
            endX -= 50; // מפחיתים כ-50 פיקסלים כדי שהאימוג'י הימני לא יצטייר מחוץ למסך
        }

        const peakY = h * 0.15 + Math.random() * (h * 0.2); 
        const finalY = h + 100;
        
        const duration = 4000 + Math.random() * 2000;
        const delay = i * 200;

        Object.assign(emojiItem.style, {
            position: 'fixed', fontSize: '2rem', zIndex: '999999', pointerEvents: 'none',
            left: '0px', top: '0px', opacity: '0'
        });
        container.appendChild(emojiItem);

        emojiItem.animate([
            { transform: `translate(${startX}px, ${startY}px) scale(0.5)`, opacity: 0 },
            { opacity: 1, offset: 0.1 },
            { transform: `translate(${endX}px, ${peakY}px) scale(1.2) rotate(360deg)`, opacity: 1, offset: 0.5 },
            { transform: `translate(${endX}px, ${finalY}px) scale(0.5) rotate(720deg)`, opacity: 0 }
        ], {
            duration: duration,
            delay: delay,
            fill: 'forwards',
            easing: 'ease-out'
        });

        setTimeout(() => { if (emojiItem.parentNode) emojiItem.remove(); }, duration + delay + 500);
    }
}