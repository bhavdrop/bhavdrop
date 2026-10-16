// store.js - Unified State Management for BhavDrop
const INITIAL_PRODUCTS = [
  {
    id: 'prod-1',
    title: 'The Sovereign Steel-Boned Velvet Corset',
    subtitle: 'French silk velvet with heavy steel boning & lace-up spine',
    category: 'her',
    price: 2499,
    originalPrice: 4200,
    sizes: ['XS (24")', 'S (26")', 'M (28")', 'L (30")'],
    colors: ['Wine Bordeaux', 'Obsidian Noir'],
    image: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=800&q=80',
    description: 'Constructed from heavy French silk-blend velvet with 16 flexible steel spiral bones that cinch without restricting breathe. Features hand-finished eyelets.'
  },
  {
    id: 'prod-2',
    title: 'Mulberry Silk Cowl Backless Gown',
    subtitle: 'Bias-cut 22 Momme pure Mulberry silk in liquid champagne',
    category: 'her',
    price: 3299,
    originalPrice: 5900,
    sizes: ['S (Bust 34)', 'M (Bust 36)', 'L (Bust 38)'],
    colors: ['Champagne Gold', 'Emerald Night'],
    image: 'https://images.unsplash.com/photo-1566174053879-31528523f8ae?auto=format&fit=crop&w=800&q=80',
    description: 'Drapes sensually across the torso with a plunged cowl back that falls to the sacrum. Hand-rolled hems and double lined bust.'
  },
  {
    id: 'prod-3',
    title: 'Italian Velvet Dinner Smoking Blazer',
    subtitle: 'Deep wine bordeaux velvet with satin peak lapels',
    category: 'him',
    price: 3899,
    originalPrice: 6500,
    sizes: ['38R (Slim)', '40R (Regular)', '42R (Tailored)', '44R (Broad)'],
    colors: ['Bordeaux Wine', 'Midnight Black'],
    image: 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?auto=format&fit=crop&w=800&q=80',
    description: 'Crafted from Italian cotton velvet with structured rope shoulders and duchess satin peak lapels. Fully lined in cupro.'
  },
  {
    id: 'prod-4',
    title: 'Semi-Sheer Shadow Striped Silk Shirt',
    subtitle: 'Ultra-lightweight mulberry georgette with mother-of-pearl buttons',
    category: 'him',
    price: 1899,
    originalPrice: 3200,
    sizes: ['M (Chest 40)', 'L (Chest 42)', 'XL (Chest 44)'],
    colors: ['Obsidian Sheer', 'Opal Fog'],
    image: 'https://images.unsplash.com/photo-1617137984095-74e4e5e3613f?auto=format&fit=crop&w=800&q=80',
    description: 'Translucent tone-on-tone alternating matte and sheen stripes. Designed to be worn unbuttoned to mid-chest.'
  },
  {
    id: 'prod-5',
    title: 'Cleopatra Serpent Emerald Choker',
    subtitle: '18K gold vermeil snake silhouette with simulated Zambian emerald eyes',
    category: 'jewels',
    price: 2899,
    originalPrice: 5200,
    sizes: ['Adjustable 14"-16"'],
    colors: ['18K Champagne Gold', 'Platinum Rhodium'],
    image: 'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?auto=format&fit=crop&w=800&q=80',
    description: 'Articulated scale vertebrae that contours smoothly against the collarbone. Set with brilliant-cut micro zirconias and deep emerald drop eyes.'
  },
  {
    id: 'prod-6',
    title: 'The Sovereign Solitaire Signet Ring',
    subtitle: 'Solid sterling silver layered in 2.5 micron 18K gold with onyx inlay',
    category: 'jewels',
    price: 1499,
    originalPrice: 2800,
    sizes: ['US 8 (18.2mm)', 'US 9 (19.0mm)', 'US 10 (19.8mm)'],
    colors: ['Gold / Black Onyx', 'Silver / Green Malachite'],
    image: 'https://images.unsplash.com/photo-1605100804763-247f67b3557e?auto=format&fit=crop&w=800&q=80',
    description: 'Substantial weighted signet with flush hand-cut natural gemstone slab. Beveled edge comfort-fit interior band.'
  }
];

const INITIAL_VAULT = {
  title: 'The Empress Emerald Royal Serpent Choker',
  subtitle: 'One-of-One Masterpiece • Sourced Hand-Cast Vermeil',
  image: 'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?auto=format&fit=crop&w=800&q=80',
  startPrice: 4999,
  floorPrice: 1499,
  dropStep: 35,
  dropIntervalSeconds: 3,
  description: 'Articulated vertebrae choker handcrafted in 2.5 micron 18K yellow gold vermeil over 925 sterling silver, set with pear-cut simulated Zambian emeralds.',
  status: 'live' // 'upcoming', 'live', 'locked', 'sold'
};

// Initialize LocalStorage Data
function initBhavStore() {
  if (!localStorage.getItem('bd_catalog')) {
    localStorage.setItem('bd_catalog', JSON.stringify(INITIAL_PRODUCTS));
  }
  if (!localStorage.getItem('bd_vault_data')) {
    localStorage.setItem('bd_vault_data', JSON.stringify(INITIAL_VAULT));
  }
  if (!localStorage.getItem('bd_cart')) {
    const old = JSON.parse(localStorage.getItem('bd_cart_items') || '[]');
    localStorage.setItem('bd_cart', JSON.stringify(old.map(i => ({...i, qty: Number(i.qty ?? i.quantity ?? 1), img: i.img || i.image || ''}))));
  }
  if (!localStorage.getItem('bd_orders_list')) {
    localStorage.setItem('bd_orders_list', JSON.stringify([]));
  }
}
initBhavStore();

// Utility Getters & Setters
function getCatalog() { return JSON.parse(localStorage.getItem('bd_catalog') || '[]'); }
function getVaultItem() { return JSON.parse(localStorage.getItem('bd_vault_data') || '{}'); }
function getCart() { return JSON.parse(localStorage.getItem('bd_cart') || '[]').map(i => ({...i, qty: Number(i.qty ?? i.quantity ?? 1), img: i.img || i.image || ''})); }
function getOrders() { return JSON.parse(localStorage.getItem('bd_orders_list') || '[]'); }

function saveCart(cart) {
  localStorage.setItem('bd_cart', JSON.stringify(cart.map(i => ({...i, qty: Number(i.qty ?? i.quantity ?? 1), img: i.img || i.image || ''}))));
  updateGlobalCartBadges();
}

function addToCart(product, selectedSize = null, selectedColor = null) {
  const cart = getCart();
  const size = selectedSize || (product.sizes ? product.sizes[0] : 'Standard');
  const color = selectedColor || (product.colors ? product.colors[0] : 'Default');
  const existing = cart.find(item => item.id === product.id && item.size === size && item.color === color);
  if (existing) {
    existing.qty = Number(existing.qty ?? existing.quantity ?? 1) + 1; existing.quantity = existing.qty;
  } else {
    cart.push({
      id: product.id,
      title: product.title,
      price: product.price,
      image: product.image,
      img: product.image,
      size,
      color,
      qty: 1,
      quantity: 1
    });
  }
  saveCart(cart);
  showToast(`Added ${product.title} to your bag`);
}

function updateGlobalCartBadges() {
  const cart = getCart();
  const totalCount = cart.reduce((acc, item) => acc + Number(item.qty ?? item.quantity ?? 1), 0);
  document.querySelectorAll('.cart-badge-count').forEach(badge => {
    badge.textContent = totalCount;
    if (totalCount > 0) {
      badge.classList.remove('hidden');
    } else {
      badge.classList.add('hidden');
    }
  });
}

function showToast(message) {
  let toast = document.getElementById('bd-global-toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'bd-global-toast';
    toast.className = 'fixed bottom-6 right-6 z-50 bg-[#161b24] border border-[#d4af37]/40 text-[#f3e5ab] text-xs font-semibold px-4 py-3 rounded-xl shadow-2xl transition-all duration-300 transform translate-y-20 opacity-0';
    document.body.appendChild(toast);
  }
  toast.textContent = message;
  toast.classList.remove('translate-y-20', 'opacity-0');
  setTimeout(() => {
    toast.classList.add('translate-y-20', 'opacity-0');
  }, 2600);
}

document.addEventListener('DOMContentLoaded', updateGlobalCartBadges);
