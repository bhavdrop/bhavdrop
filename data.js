// data.js - Universal Store Engine
function getCart() {
  return JSON.parse(localStorage.getItem('bd_cart') || '[]');
}

function saveCart(cart) {
  localStorage.setItem('bd_cart', JSON.stringify(cart));
  updateBadges();
}

function addToCart(item, selectedSize = null) {
  const cart = getCart();
  const size = selectedSize || (item.sizes ? item.sizes[0] : 'Standard');
  const existing = cart.find(i => i.id === item.id && i.size === size);

  if (existing) {
    existing.qty += 1;
  } else {
    cart.push({
      id: item.id,
      title: item.title,
      price: Number(item.price),
      img: item.images ? item.images[0] : item.image,
      size: size,
      qty: 1
    });
  }
  saveCart(cart);
  showToast(`Added ${item.title} to your bag`);
}

function updateBadges() {
  const count = getCart().reduce((sum, i) => sum + i.qty, 0);
  document.querySelectorAll('.cart-badge-count').forEach(el => {
    el.innerText = count;
    el.classList.toggle('hidden', count === 0);
  });
}

function showToast(msg) {
  let toast = document.getElementById('bd-toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'bd-toast';
    toast.className = 'fixed bottom-6 right-6 z-50 bg-[#1a1a1a] text-stone-100 text-xs px-5 py-3 rounded-2xl shadow-xl transition-all duration-300 transform translate-y-20 opacity-0';
    document.body.appendChild(toast);
  }
  toast.innerText = msg;
  toast.classList.remove('translate-y-20', 'opacity-0');
  setTimeout(() => toast.classList.add('translate-y-20', 'opacity-0'), 2500);
}

document.addEventListener('DOMContentLoaded', updateBadges);
