// BhavDrop shared browser utilities. Cart is local to this browser; it is not trusted for pricing.
(function () {
  const CART_KEY = 'bd_cart';
  const OLD_CART_KEY = 'bd_cart_items';
  const FALLBACK_IMAGE = 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=600&q=80';

  function readJSON(key, fallback) {
    try {
      const value = localStorage.getItem(key);
      return value ? JSON.parse(value) : fallback;
    } catch (error) {
      console.warn(`BhavDrop: could not read ${key}; using fallback.`, error);
      return fallback;
    }
  }

  function normalizeItem(item) {
    const qty = Number(item?.qty ?? item?.quantity ?? 1);
    const images = Array.isArray(item?.images) ? item.images : [];
    return {
      ...item,
      id: String(item?.id ?? ''),
      title: String(item?.title ?? 'Product'),
      price: Number(item?.price ?? 0),
      qty: Number.isFinite(qty) && qty > 0 ? Math.floor(qty) : 1,
      img: String(item?.img || item?.image || images[0] || FALLBACK_IMAGE),
      size: String(item?.size || 'Standard'),
      color: String(item?.color || 'Default')
    };
  }

  window.getCart = function () {
    const current = readJSON(CART_KEY, null);
    const legacy = current === null ? readJSON(OLD_CART_KEY, []) : current;
    const cart = Array.isArray(legacy) ? legacy.map(normalizeItem) : [];
    if (current === null && cart.length) window.saveCart(cart);
    return cart;
  };

  window.saveCart = function (cart) {
    const normalized = Array.isArray(cart) ? cart.map(normalizeItem) : [];
    localStorage.setItem(CART_KEY, JSON.stringify(normalized));
    localStorage.removeItem(OLD_CART_KEY);
    window.updateBadges();
  };

  window.addToCart = function (product, selectedSize = 'Standard', selectedColor = 'Default') {
    if (!product || typeof product !== 'object' || product.id == null) {
      window.showToast('Could not add this product. Please reload the page.');
      return;
    }
    const cart = window.getCart();
    const normalized = normalizeItem({
      ...product,
      img: product.img || product.image || (Array.isArray(product.images) ? product.images[0] : '') || FALLBACK_IMAGE,
      qty: 1,
      size: selectedSize || (Array.isArray(product.sizes) ? product.sizes[0] : 'Standard'),
      color: selectedColor || (Array.isArray(product.colors) ? product.colors[0] : 'Default')
    });
    const existing = cart.find(i => i.id === normalized.id && i.size === normalized.size && i.color === normalized.color);
    if (existing) existing.qty += 1;
    else cart.push(normalized);
    window.saveCart(cart);
    window.showToast(`Added ${normalized.title} to your bag`);
  };

  window.updateBadges = function () {
    let count = 0;
    try { count = window.getCart().reduce((sum, item) => sum + item.qty, 0); } catch (_) {}
    document.querySelectorAll('.cart-badge-count').forEach(el => {
      el.textContent = String(count);
      el.classList.toggle('hidden', count < 1);
    });
  };

  window.showToast = function (message) {
    let toast = document.getElementById('bd-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'bd-toast';
      toast.className = 'fixed bottom-6 right-6 z-50 bg-black text-white text-xs px-5 py-3 shadow-2xl transition-all duration-300 transform translate-y-20 opacity-0';
      toast.setAttribute('role', 'status');
      document.body.appendChild(toast);
    }
    toast.textContent = String(message);
    toast.classList.remove('translate-y-20', 'opacity-0');
    clearTimeout(window.__bdToastTimeout);
    window.__bdToastTimeout = setTimeout(() => toast.classList.add('translate-y-20', 'opacity-0'), 2400);
  };

  document.addEventListener('DOMContentLoaded', window.updateBadges);
})();
