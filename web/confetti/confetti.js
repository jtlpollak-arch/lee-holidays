function launchContextualConfetti() {
    const container = document.getElementById('confetti-container');
    if (!container) return;
    
    container.innerHTML = ''; 

    // הגדרת מאגרי האווירה
    const moods = {
        realEstate: ['🏠', '🏡', '🔑', '🗝️', '💖', '🪴', '✨', '💎', '🥂', '🌟', '🌸', '🌷', '🦋', '🧡', '🌞']
    };

    const moodKeys = Object.keys(moods);
    const chosenMood = moodKeys[Math.floor(Math.random() * moodKeys.length)];
    const emojiPool = moods[chosenMood];

    // התאמת כמות החלקיקים לגודל המסך
    const numberOfEmojis = 25;
    
    const fragment = document.createDocumentFragment();

    // לקיחת המימד הקטן יותר (רוחב או גובה) כדי לשמור על רדיוס פיצוץ מעגלי ופרופורציונלי
    const minScreenDimension = Math.min(window.innerWidth, window.innerHeight);

    for (let i = 0; i < numberOfEmojis; i++) {
        const emojiItem = document.createElement('div');
        emojiItem.classList.add('wow-confetti-item');

        if (Math.random() < 0.1) {
            emojiItem.innerText = '🔑'; 
        } else {
            emojiItem.innerText = emojiPool[Math.floor(Math.random() * emojiPool.length)];
        }

        // חישוב זווית (0 עד 360 מעלות ברדיאנים)
        const angle = Math.random() * Math.PI * 2; 
        
        // עוצמת ההדף כמרחק בפיקסלים (בין 10% ל-45% מהמסך הקטן)
        const velocity = Math.random() * (minScreenDimension * 0.35) + (minScreenDimension * 0.1); 
        
        // חישוב מרחק תנועה אופקי ונקודת שיא הגובה בפיקסלים מדויקים
        const tx = Math.cos(angle) * velocity;
        const tyUp = -Math.abs(Math.sin(angle) * velocity) - (minScreenDimension * 0.1); // דחיפה מינימלית למעלה
        
        // סיבובים למראה תלת מימדי באוויר
        const rotX = Math.random() * 1080;
        const rotY = Math.random() * 1080;
        const rotZ = Math.random() * 1080;
        
        const scale = Math.random() * 0.8 + 0.6;
        const duration = 10 // בין 5 ל-7 שניות
        const delay = 0; 

        // העברת הנתונים ל-CSS (עכשיו בפיקסלים במקום vw/vh)
        emojiItem.style.setProperty('--tx', `${tx}px`);
        emojiItem.style.setProperty('--ty-up', `${tyUp}px`);
        emojiItem.style.setProperty('--rot-x', `${rotX}deg`);
        emojiItem.style.setProperty('--rot-y', `${rotY}deg`);
        emojiItem.style.setProperty('--rot-z', `${rotZ}deg`);
        emojiItem.style.setProperty('--scale', scale);
        
        emojiItem.style.animationDuration = `${duration}s`;
        emojiItem.style.animationDelay = `${delay}s`;

        fragment.appendChild(emojiItem);
        
        // ניקוי
        setTimeout(() => { 
            if (emojiItem.parentNode) {
                emojiItem.remove(); 
            }
            console.log("מחקתי קונפטי");
        }, (duration + delay) * 1000);
    }

    container.appendChild(fragment);
}