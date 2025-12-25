import { getTunnel, getHealth } from '$lib/api';

class UIStore {
  // Sidebar
  sidebarCollapsed = $state(false);
  
  // Density
  compactMode = $state(false);
  
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

  // Initialization
  init() {
    // Load preferences from localStorage
    if (typeof window !== 'undefined') {
      this.sidebarCollapsed = localStorage.getItem('sidebarCollapsed') === '1';
      this.compactMode = localStorage.getItem('densityCompact') === '1';
      
      if (this.compactMode) {
        document.body.classList.add('compact');
      }
    }
  }

  // Sidebar
  toggleSidebar() {
    this.sidebarCollapsed = !this.sidebarCollapsed;
    localStorage.setItem('sidebarCollapsed', this.sidebarCollapsed ? '1' : '0');
  }

  // Density
  toggleDensity() {
    this.compactMode = !this.compactMode;
    localStorage.setItem('densityCompact', this.compactMode ? '1' : '0');
    
    if (this.compactMode) {
      document.body.classList.add('compact');
    } else {
      document.body.classList.remove('compact');
    }
  }

  // Navigation
  setActiveSection(section: string) {
    this.activeSection = section;
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

