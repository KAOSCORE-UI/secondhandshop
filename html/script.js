let currentImagePath = "";
let playerCitizenId = "";

window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.action === "openShop") {
        currentImagePath = data.imagePath;
        playerCitizenId = data.playerCitizenId;
        setupShop(data.items);
        $('#app').fadeIn(200);
    }
});

function setupShop(items) {
    $('#itemsGrid').empty();
    
    if (!items || items.length === 0) {
        $('#itemsGrid').hide();
        $('#emptyState').show();
        return;
    }

    $('#itemsGrid').show();
    $('#emptyState').hide();

    items.forEach(item => {
        let nameFormatted = item.item_name.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
        let imgSrc = currentImagePath + item.item_name + ".png";
        
        let metadata = {};
        try {
            metadata = JSON.parse(item.metadata) || {};
        } catch(e) {}
        
        let qualityHtml = "";
        let durability = metadata.quality !== undefined ? metadata.quality : (metadata.durability !== undefined ? metadata.durability : null);
        
        if (durability !== null) {
            let color = "#10b981"; // green
            if (durability < 25) color = "#ef4444"; // red
            else if (durability < 50) color = "#f59e0b"; // yellow
            
            let warningHtml = "";
            if (durability <= 15) {
                warningHtml = `<div style="color: #ef4444; font-size: 11px; font-weight: bold; margin-bottom: 5px; text-align: center; animation: pulse 1.5s infinite;"><i class="fas fa-exclamation-triangle"></i> About to break</div>`;
            }
            
            qualityHtml = `
                <div class="quality-container" style="width: 90%; background: rgba(0,0,0,0.4); border-radius: 4px; margin-bottom: 8px; height: 6px; overflow: hidden; border: 1px solid rgba(255,255,255,0.1);">
                    <div style="width: ${durability}%; height: 100%; background: ${color};"></div>
                </div>
                ${warningHtml}
            `;
        }
        
        let actionBtn = "";
        if (item.citizenid === playerCitizenId) {
            actionBtn = `
                <button class="cancel-btn" onclick="cancelListing(${item.id})" style="background: #4b5563; width: 100%; color: white; border: none; padding: 10px; border-radius: 6px; font-size: 14px; font-weight: 600; cursor: pointer; transition: 0.2s; display: flex; justify-content: center; align-items: center; gap: 8px;" onmouseover="this.style.background='#374151'" onmouseout="this.style.background='#4b5563'">
                    <i class="fas fa-undo"></i> Cancel Listing
                </button>
            `;
        } else {
            actionBtn = `
                <button class="buy-btn" onclick="buyItem(${item.id}, ${item.price})">
                    <i class="fas fa-shopping-cart"></i> $${item.price.toLocaleString()}
                </button>
            `;
        }
        
        let card = `
            <div class="item-card">
                <div class="item-amount">${item.amount}x</div>
                <img src="${imgSrc}" class="item-image" onerror="this.src='https://cfx-nui-qb-inventory/html/images/default.png'; this.onerror=null;" alt="${nameFormatted}">
                <div class="item-name">${nameFormatted}</div>
                ${qualityHtml}
                <div class="item-seller"><i class="fas fa-user-tag"></i> ${item.seller_name}</div>
                ${actionBtn}
            </div>
        `;
        $('#itemsGrid').append(card);
    });
}

function buyItem(id, price) {
    $.post('https://secondhandshop/buyItem', JSON.stringify({
        id: id,
        price: price
    }));
    closeMenu();
}

function cancelListing(id) {
    $.post('https://secondhandshop/cancelListing', JSON.stringify({
        id: id
    }));
    closeMenu();
}

function closeMenu() {
    $('#app').fadeOut(200);
    $.post('https://secondhandshop/closeMenu', JSON.stringify({}));
}

$('#closeBtn').click(function() {
    closeMenu();
});

// Close on escape key
document.onkeyup = function(data) {
    if (data.which == 27) {
        closeMenu();
    }
};
