function launchContextualConfetti() {
    console.log("[CONF-DEBUG] -> תחילת הפעלת אפקט מזרקת האימוג'ים.");
    const container = document.getElementById('confetti-container');
    if (!container) return;

    container.innerHTML = ''; 
    const emojiPool = ['🏠', '🏡', '🔑', '🗝️', '💖', '🪴', '✨', '💎', '🥂', '🌟', '🌸', '🌷', '🦋', '🧡', '🌞'];
    const numberOfEmojis = 35; 
    const w = window.innerWidth;
    const h = window.innerHeight;

    for (let i = 0; i < numberOfEmojis; i++) {
        const emojiItem = document.createElement('div');
        emojiItem.classList.add('wow-confetti-item');
        emojiItem.innerText = Math.random() < 0.1 ? '🔑' : emojiPool[Math.floor(Math.random() * emojiPool.length)];

        // שינוי הוקטור: מתחילים מהתחתית (h + 50)
        const startX = w / 2; // מתחילים מהמרכז
        const startY = h + 50; 
        
        // יעד: התפזרות אופקית וגובה השיא של המזרקה
        const endX = startX + (Math.random() - 0.5) * (w * 0.8);
        const peakY = h * 0.2 + Math.random() * (h * 0.3); // שיא הגובה: בין 20% ל-50% מגובה המסך
        const finalY = h + 100; // נופלים חזרה למטה
        
        const duration = 4000 + Math.random() * 2000;
        const delay = i * 200; // דירוג יציאה אחד-אחד

        Object.assign(emojiItem.style, {
            position: 'fixed', fontSize: '2rem', zIndex: '999999', pointerEvents: 'none',
            left: '0px', top: '0px', opacity: '0'
        });
        container.appendChild(emojiItem);

        console.log(`[CONF-DEBUG] -> משגר אימוג'י ${i} בתזמון ${delay}ms`);

        // אנימציית קשת (מזרקה)
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