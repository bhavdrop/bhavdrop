// data.js - Central Bag & Global Utilities
function getCart() {
  return JSON.parse(localStorage.getItem('bd_cart') || '[]');
}

function saveCart(cart) {
  localStorage.setItem('bd_cart', JSON.stringify(cart));
  updateBadges();
}

function addToCart(item, selectedSize = 'Standard') {
  const cart = getCart();
  const existing = cart.find(i => i.id === item.id && i.size === selectedSize);
  
  if (existing) {
    existing.qty += 1;
  } else {
    cart.push({
      id: item.id,
      title: item.title,
      price: Number(item.price),
      img: item.images ? item.images[0] : (item.image || 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=600&q=80'),
      size: selectedSize,
      qty: 1
    });
  }
  saveCart(cart);
  showToast(`Added ${item.title} to bag`);
}

function updateBadges() {
  const count = getCart().reduce((sum, i) => sum + i.qty, 0);
  document.querySelectorAll('.cart-badge-count').forEach(el => {
    el.innerText = count;
  });
}

function showToast(msg) {
  let toast = document.getElementById('bd-toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'bd-toast';
    toast.className = 'fixed bottom-6 right-6 z-50 bg-black text-white text-xs px-5 py-3 shadow-2xl transition-all duration-300 transform translate-y-20 opacity-0';
    document.body.appendChild(toast);
  }
  toast.innerText = msg;
  toast.classList.remove('translate-y-20', 'opacity-0');
  setTimeout(() => toast.classList.add('translate-y-20', 'opacity-0'), 2400);
}

document.addEventListener('DOMContentLoaded', updateBadges);
