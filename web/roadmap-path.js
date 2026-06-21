window.roadMapIsRunning = false;

function drawRoadmap() {
    window.roadMapIsRunning = true;
    const canvas = document.getElementById('roadmap-canvas');
    if (!canvas) return;

    const connectionOrder = [
        '.logo-wrapper', '.lee-course-svg', '.lee-key-container-svg', 
        '.lee-safe-home-svg', '.lee-handshake-svg'
    ];

    const points = getRoadmapPoints(connectionOrder);
    if (points.length < 2) return;

    const pathDataAndMetrics = buildPathAndMeasure(points);
    
    renderRoadmap(canvas, pathDataAndMetrics.pathData);

    scheduleAnimations(canvas, pathDataAndMetrics, connectionOrder);
}

function getRoadmapPoints(connectionOrder) {
    const points = [];
    connectionOrder.forEach(selector => {
        const el = document.querySelector(selector);
        if (el) {
            const rect = el.getBoundingClientRect();
            points.push({ x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 });
        }
    });
    return points;
}

function buildPathAndMeasure(points) {
    let pathData = "";
    let exactTotalLength = 0;
    const distanceSegments = [];
    const startX = -5;
    const startY = window.innerHeight + 40;

    const firstSegmentD = `M ${startX} ${startY} C ${startX} ${points[0].y + (startY - points[0].y) * 0.4}, ${points[0].x * 0.5} ${points[0].y}, ${points[0].x} ${points[0].y}`;
    pathData += firstSegmentD;

    const tempPath0 = document.createElementNS("http://www.w3.org/2000/svg", "path");
    tempPath0.setAttribute("d", firstSegmentD);
    exactTotalLength += tempPath0.getTotalLength();
    distanceSegments.push(exactTotalLength);

    for (let i = 1; i < points.length; i++) {
        const prev = points[i - 1], curr = points[i];
        const dx = curr.x - prev.x, dy = curr.y - prev.y;
        const midX = prev.x + dx / 2, midY = prev.y + dy / 2;
        const length = Math.sqrt(dx * dx + dy * dy);
        const perpX = length > 0 ? -dy / length : 0;
        const perpY = length > 0 ? dx / length : 0;
        const offsetAmount = Math.min(80, length / 3);
        const direction = (i % 2 === 0) ? 1 : -1;
        
        const segmentD = ` Q ${midX + perpX * offsetAmount * direction} ${midY + perpY * offsetAmount * direction}, ${curr.x} ${curr.y}`;
        pathData += segmentD;

        const tempPath = document.createElementNS("http://www.w3.org/2000/svg", "path");
        tempPath.setAttribute("d", `M ${prev.x} ${prev.y}` + segmentD);
        exactTotalLength += tempPath.getTotalLength();
        distanceSegments.push(exactTotalLength);
    }
    return { pathData, distanceSegments, exactTotalLength };
}


function renderRoadmap(canvas, pathData) {
    canvas.innerHTML = `
        <defs>
            <filter id="particle-glow" x="-50%" y="-50%" width="200%" height="200%">
                <feGaussianBlur stdDeviation="3" result="blur" />
                <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
            </filter>
        </defs>
        <path class="roadmap-line" d="${pathData}"></path>
        <circle class="traveling-particle" r="6" fill="#FFD700" filter="url(#particle-glow)">
            <animateMotion id="particle-motion" dur="10s" repeatCount="1" fill="freeze" path="${pathData}" begin="indefinite" />
        </circle>
    `;
}


function scheduleAnimations(canvas, metrics, connectionOrder) {
    const { distanceSegments, exactTotalLength } = metrics;
    
    setTimeout(() => {
        const line = canvas.querySelector('.roadmap-line');
        const particle = canvas.querySelector('.traveling-particle');
        const motion = canvas.querySelector('#particle-motion');
        const handshake = document.querySelector('.lee-handshake-svg');

        if (line) line.classList.add('visible');

        if (particle && motion) {
            setTimeout(() => {
                particle.classList.add('active');
                motion.beginElement();

                connectionOrder.forEach((selector, index) => {
                    if (index === connectionOrder.length - 1) return;
                    const el = document.querySelector(selector);
                    if (!el) return;
                    
                    const delayMs = (distanceSegments[index] / exactTotalLength) * 10000;
                    setTimeout(() => el.classList.add('node-pulse'), delayMs);
                });

                setTimeout(() => {
                    particle.classList.add('absorbed');
                    if (handshake) {
                        handshake.classList.add('pulsate-active');
                        window.roadMapIsRunning = false;
                    }
                }, 10000);
            }, 500);
        }
    }, 100);
}

/*************************************************************************** */

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