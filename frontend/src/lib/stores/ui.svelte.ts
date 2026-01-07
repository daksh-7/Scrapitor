import { getTunnel, getHealth } from '$lib/api';

class UIStore {
  // Endpoints
  cloudflareUrl = $state('');
  localUrl = $state('http://localhost:5000/openrouter-cc');
  port = $state(5000);

  // Notifications
  notifications = $state<Array<{ id: number; message: string; type: 'success' | 'error' | 'info' | 'warning' }>>([]);
  private notificationId = 0;

  // Active section (for nav highlighting)
  activeSection = $state('overview');

  // Loading state
  loading = $state(false);

  // Mobile navigation state
  mobileMenuOpen = $state(false);
  isMobile = $state(false);

  constructor() {
    // Check if we're in a browser environment
    if (typeof window !== 'undefined') {
      this.checkMobile();
      window.addEventListener('resize', () => this.checkMobile());
    }
  }

  private checkMobile() {
    this.isMobile = window.innerWidth < 768;
    // Close menu when switching to desktop
    if (!this.isMobile) {
      this.mobileMenuOpen = false;
    }
  }

  toggleMobileMenu() {
    this.mobileMenuOpen = !this.mobileMenuOpen;
  }

  closeMobileMenu() {
    this.mobileMenuOpen = false;
  }

  // Navigation
  setActiveSection(section: string) {
    this.activeSection = section;
    // Close mobile menu when navigating
    this.closeMobileMenu();
  }

  // Endpoints
  async refreshEndpoints() {
    try {
      const [tunnel, health] = await Promise.all([
        getTunnel(),
        getHealth(),
      ]);
      
      if (tunnel.url) {
        this.cloudflareUrl = `${tunnel.url}/openrouter-cc`;
      }
      
      if (health.config?.port) {
        this.port = health.config.port;
        this.localUrl = `http://localhost:${this.port}/openrouter-cc`;
      }
    } catch {
      // Silent fail - endpoints may not be available yet
    }
  }

  // Notifications
  notify(message: string, type: 'success' | 'error' | 'info' | 'warning' = 'success') {
    const id = ++this.notificationId;
    this.notifications = [...this.notifications, { id, message, type }];
    
    // Auto-remove after 3 seconds
    setTimeout(() => {
      this.dismissNotification(id);
    }, 3000);
  }

  dismissNotification(id: number) {
    this.notifications = this.notifications.filter(n => n.id !== id);
  }

  // Clipboard
  async copyToClipboard(text: string): Promise<boolean> {
    try {
      await navigator.clipboard.writeText(text);
      this.notify('Copied to clipboard');
      return true;
    } catch {
      this.notify('Failed to copy', 'error');
      return false;
    }
  }
}

export const uiStore = new UIStore();
