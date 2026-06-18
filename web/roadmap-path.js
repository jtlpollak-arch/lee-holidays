window.roadMapIsRunning = false;

function drawRoadmap() {
    window.roadMapIsRunning = true;

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

    // --- הזרקת "תחנת אפס" וירטואלית קולנועית (מחוץ למסך משמאל למטה) ---
    const startX = -5; 
    const startY = window.innerHeight + 40; 

    // משתנים למדידה פיזיקלית מדויקת של המסלול
    let exactTotalLength = 0;
    const distanceSegments = []; 
    let pathData = "";
    
    // 3. בניית הציור ומדידת המקטעים
    
    // --- מקטע 1: עקומת הטיפוס הקולנועית (Cubic Bézier מלמטה) ---
    const cp1X = startX;                                      
    const cp1Y = points[0].y + (startY - points[0].y) * 0.4;  
    const cp2X = points[0].x * 0.5;                           
    const cp2Y = points[0].y;                                 

    const firstSegmentD = `M ${startX} ${startY} C ${cp1X} ${cp1Y}, ${cp2X} ${cp2Y}, ${points[0].x} ${points[0].y}`; 
    pathData += firstSegmentD;

    // מדידה מדויקת של המקטע הראשון
    const tempPath0 = document.createElementNS("http://www.w3.org/2000/svg", "path");
    tempPath0.setAttribute("d", firstSegmentD);
    exactTotalLength += tempPath0.getTotalLength();
    distanceSegments.push(exactTotalLength); // אינדקס 0: נקודת הזמן המדויקת ללוגו
    
    // --- מקטע 2: המשך בניית הנתיב המפותל ומדידת העקומות ---
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
        
        const segmentD = ` Q ${cpX} ${cpY}, ${curr.x} ${curr.y}`;
        pathData += segmentD;

        // מדידה מדויקת של המקטע הנוכחי כולל העיקול
        const tempPath = document.createElementNS("http://www.w3.org/2000/svg", "path");
        tempPath.setAttribute("d", `M ${prev.x} ${prev.y}` + segmentD);
        exactTotalLength += tempPath.getTotalLength();
        distanceSegments.push(exactTotalLength);
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
            <animateMotion id="particle-motion" dur="10s" repeatCount="1" fill="freeze" path="${pathData}" begin="indefinite" />
        </circle>
    `;

    // 5. ניהול האנימציה ותזמון הפעימה
    setTimeout(() => {
        const line = canvas.querySelector('.roadmap-line');
        const particle = canvas.querySelector('.traveling-particle');
        const motion = canvas.querySelector('#particle-motion');
        const handshake = document.querySelector('.lee-handshake-svg'); 
        
        if (line) {
            line.classList.add('visible');
        }
        
        if (particle && motion) {
            // ממתינים להופעת הקו ואז משגרים את החלקיק
            setTimeout(() => {
                particle.classList.add('active');
                motion.beginElement(); 
                
                // --- תזמון פעימות המעבר לתחנות (במדידה פיזיקלית מדויקת מתוך 10 שניות) ---
                connectionOrder.forEach((selector, index) => {
                    // מדלגים על לחיצת היד (מטופלת בנפרד בסוף)
                    if (index === connectionOrder.length - 1) return; 
                    
                    const el = document.querySelector(selector);
                    if (!el) return;
                    
                    // חישוב הזמן המדויק לפי האורך האמיתי שהחלקיק נסע עד לנקודה זו
                    const delayMs = (distanceSegments[index] / exactTotalLength) * 10000;
                    
                    setTimeout(() => {
                        el.classList.add('node-pulse');
                    }, delayMs);
                });
                
                // --- טיימר לסיום המסע (10 שניות בדיוק) ---
                setTimeout(() => {
                    // א. מעלימים את החלקיק (הוא נבלע ביד)
                    particle.classList.add('absorbed');
                    
                    // ב. מדליקים את פעימת הזהב של לחיצת היד
                    if (handshake) {
                        handshake.classList.add('pulsate-active');
                        console.log("<--drawRoadmap--> המסע הושלם! היד פועמת בזהב. סנכרון מדויק.");
                        window.roadMapIsRunning = false;
                    }
                }, 10000);

            }, 500);
        }
    }, 100);
}

function cleanRoadmap(){
    // נקיון
    document.querySelectorAll('.page-content').forEach(p => p.classList.remove('dim-page'));
    
    // מחיקת הקלאסים כדי שאם משחזרים את האנימציה היא תוכל לקרות שוב
    document.querySelectorAll('.lee-key-container-svg, .lee-course-svg, .lee-safe-home-svg, .logo-wrapper, .lee-handshake-svg')
        .forEach(el => {
            el.classList.remove('visible-corner');
            el.classList.remove('node-pulse');
        });
        
    document.querySelectorAll('.signature-wrapper').forEach(s => s.classList.remove('show-signature'));
    
    const roadmapCanvas = document.getElementById('roadmap-canvas');
    if (roadmapCanvas) {
        roadmapCanvas.innerHTML = '';
    }

    const handshake = document.querySelector('.lee-handshake-svg');
    if (handshake) {
        handshake.classList.remove('pulsate-active');
    }
}