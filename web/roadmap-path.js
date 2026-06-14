function drawRoadmap() {
    const canvas = document.getElementById('roadmap-canvas');
    if (!canvas) return;

    // 1. הסדר שבו הקו יחבר את האלמנטים
    const connectionOrder = [
        '.logo-wrapper',
        '.lee-course-svg',
        '.lee-key-container-svg',
        '.lee-safe-home-svg',
        '.lee-handshake-svg'
    ];

    const points = [];

    // 2. איסוף נקודות הציון המדויקות
    connectionOrder.forEach(selector => {
        const el = document.querySelector(selector);
        if (el) {
            const rect = el.getBoundingClientRect();
            points.push({
                x: rect.left + rect.width / 2,
                y: rect.top + rect.height / 2
            });
        }
    });

    if (points.length < 2) {
        console.log("לא נמצאו מספיק אלמנטים כדי לצייר מסלול");
        return;
    }

    // 3. בניית הציור (נתיב גלי ומתפתל)
    let pathData = `M ${points[0].x} ${points[0].y}`; 
    
    for (let i = 1; i < points.length; i++) {
        const prev = points[i - 1];
        const curr = points[i];
        
        const dx = curr.x - prev.x;
        const dy = curr.y - prev.y;
        const midX = prev.x + dx / 2;
        const midY = prev.y + dy / 2;
        
        const length = Math.sqrt(dx * dx + dy * dy);
        let perpX = 0;
        let perpY = 0;
        
        if (length > 0) {
            perpX = -dy / length;
            perpY = dx / length;
        }
        
        const offsetAmount = Math.min(80, length / 3);
        const direction = (i % 2 === 0) ? 1 : -1; 
        
        const cpX = midX + perpX * offsetAmount * direction;
        const cpY = midY + perpY * offsetAmount * direction;
        
        pathData += ` Q ${cpX} ${cpY}, ${curr.x} ${curr.y}`;
    }

    // 4. הזרקת הציור לקנבס
    canvas.innerHTML = `
        <defs>
            <filter id="particle-glow" x="-50%" y="-50%" width="200%" height="200%">
                <feGaussianBlur stdDeviation="3" result="blur" />
                <feMerge>
                    <feMergeNode in="blur"/>
                    <feMergeNode in="SourceGraphic"/>
                </feMerge>
            </filter>
        </defs>
        
        <path class="roadmap-line" d="${pathData}"></path>
        
        <circle class="traveling-particle" r="6" fill="#FFD700" filter="url(#particle-glow)">
            <animateMotion id="particle-motion" dur="3s" repeatCount="1" fill="freeze" path="${pathData}" begin="indefinite" />
        </circle>
    `;

    // 5. ניהול האנימציה ותזמון הפעימה
    setTimeout(() => {
        const line = canvas.querySelector('.roadmap-line');
        const particle = canvas.querySelector('.traveling-particle');
        const motion = canvas.querySelector('#particle-motion');
        const handshake = document.querySelector('.lee-handshake-svg'); // תופסים את היד
        
        if (line) {
            line.classList.add('visible');
        }
        
        if (particle && motion) {
            // ממתינים להופעת הקו ואז משגרים את החלקיק
            setTimeout(() => {
                particle.classList.add('active');
                motion.beginElement(); 
                
                // --- הקסם החדש: טיימר לסיום המסע (3 שניות בדיוק) ---
                setTimeout(() => {
                    // א. מעלימים את החלקיק (הוא נבלע ביד)
                    particle.classList.add('absorbed');
                    
                    // ב. מדליקים את פעימת הזהב של לחיצת היד
                    if (handshake) {
                        handshake.classList.add('pulsate-active');
                        console.log("<--drawRoadmap--> המסע הושלם! היד פועמת בזהב.");
                    }
                }, 3000);

            }, 500);
        }
    }, 100);
}