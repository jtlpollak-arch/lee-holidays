// thank-button.js
function initThankButton() {
    const container = document.createElement('div');
    container.className = 'thank-fab-container';
    container.innerHTML = `
        <span class="thank-label">חזרו אליי</span>
    `;

    document.body.appendChild(container);

    // התרחבות אחרי 4 שניות
    setTimeout(() => {
        if (container) container.classList.add('expanded');
    }, 4000);

    container.addEventListener('click', () => {
        // הטקסט עצמו מקודד (כפי שעשית), וזה מעולה
        const message = `היי, מעוניין בפרטים בנושא ברכות בתצורה אישית.`;
        const phone = "972545324964";
        
        // יצירת הלינק המלא עם הקידוד
        const whatsappUrl = `whatsapp://send?phone=${phone}&text=${encodeURIComponent(message)}`;
        
        window.location.href = whatsappUrl;
    });
}