/**
 * CloudNestle Authentication Manager
 * Handles both registration-required and authentication-required pages
 * Competitive Advantage: Seamless user experience with progressive engagement
 */

class CloudNestleAuthManager {
  constructor() {
    this.apiBaseUrl = 'https://api.cloudnestle.com'; // Will be updated with actual API Gateway URL
    this.init();
  }

  init() {
    this.initializePageAccess();
    this.setupEventListeners();
    this.startSpotMonitoring();
  }

  initializePageAccess() {
    const accessLevel = document.querySelector('meta[name="access-level"]')?.content;
    const authType = document.querySelector('meta[name="auth-type"]')?.content;

    switch (accessLevel) {
      case 'registration':
        this.handleRegistrationRequired();
        break;
      case 'authenticated':
        this.handleAuthenticationRequired();
        break;
      case 'public':
      default:
        this.handlePublicAccess();
        break;
    }
  }

  // Registration Required Pages (Email-only access)
  handleRegistrationRequired() {
    const userEmail = localStorage.getItem('user_email');
    const registrationDate = localStorage.getItem('registration_date');

    if (!userEmail || this.isRegistrationExpired(registrationDate)) {
      this.showEmailCaptureModal();
    } else {
      this.showRegisteredContent();
      this.trackEngagement('registration_content_viewed');
    }
  }

  showEmailCaptureModal() {
    const modal = document.createElement('div');
    modal.className = 'auth-modal';
    modal.innerHTML = `
      <div class="modal-content">
        <div class="modal-header">
          <h3>🚀 Access Premium AWS Content</h3>
          <p>Join 10,000+ AWS professionals getting exclusive insights</p>
        </div>
        
        <form id="email-capture-form" class="email-capture-form">
          <div class="form-group">
            <input 
              type="email" 
              id="user-email" 
              placeholder="Enter your professional email" 
              required
              autocomplete="email"
            >
          </div>
          
          <div class="form-group">
            <input 
              type="text" 
              id="user-name" 
              placeholder="Your name (optional)"
              autocomplete="name"
            >
          </div>
          
          <div class="form-group">
            <input 
              type="text" 
              id="user-company" 
              placeholder="Company (optional)"
              autocomplete="organization"
            >
          </div>
          
          <button type="submit" class="btn btn-primary">
            Get Free Access
          </button>
          
          <p class="privacy-note">
            We respect your privacy. Unsubscribe anytime.
          </p>
        </form>
        
        <div class="competitive-advantages">
          <h4>Why CloudNestle?</h4>
          <ul>
            <li>✅ Industry-specific AWS expertise (Education, Retail, SMB)</li>
            <li>✅ AI-powered architecture analysis</li>
            <li>✅ Outcome guarantees with insurance backing</li>
            <li>✅ Community of 10,000+ AWS professionals</li>
          </ul>
        </div>
      </div>
    `;

    document.body.appendChild(modal);
    document.getElementById('user-email').focus();

    document.getElementById('email-capture-form').addEventListener('submit', (e) => {
      e.preventDefault();
      const email = document.getElementById('user-email').value;
      const name = document.getElementById('user-name').value;
      const company = document.getElementById('user-company').value;
      
      this.captureRegistration({ email, name, company });
    });

    // Close on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        modal.remove();
      }
    });
  }

  async captureRegistration({ email, name, company }) {
    try {
      // Store locally first
      localStorage.setItem('user_email', email);
      localStorage.setItem('user_name', name || '');
      localStorage.setItem('user_company', company || '');
      localStorage.setItem('registration_date', new Date().toISOString());

      // Send to external services (HubSpot, Mailchimp, etc.)
      await this.sendToEmailService({ email, name, company });

      // Track conversion
      this.trackEngagement('email_captured', { email, name, company });

      // Remove modal and show content
      document.querySelector('.auth-modal')?.remove();
      this.showRegisteredContent();

      // Show success message
      this.showNotification('✅ Access granted! Welcome to CloudNestle premium content.', 'success');

    } catch (error) {
      console.error('Registration capture failed:', error);
      this.showNotification('⚠️ Registration failed. Please try again.', 'error');
    }
  }

  showRegisteredContent() {
    document.querySelectorAll('.content-registration-required').forEach(el => {
      el.classList.remove('gated');
    });

    // Show personalized welcome message
    const userName = localStorage.getItem('user_name');
    if (userName) {
      this.showNotification(`Welcome back, ${userName}! 👋`, 'info');
    }
  }

  // Authentication Required Pages (Full profile access)
  async handleAuthenticationRequired() {
    const token = localStorage.getItem('auth_token');
    
    if (!token || this.isTokenExpired(token)) {
      this.redirectToLogin();
      return;
    }

    try {
      const isValid = await this.validateToken(token);
      if (isValid) {
        this.showAuthenticatedContent();
        this.loadUserProfile();
      } else {
        this.redirectToLogin();
      }
    } catch (error) {
      console.error('Authentication check failed:', error);
      this.redirectToLogin();
    }
  }

  async validateToken(token) {
    try {
      const response = await fetch(`${this.apiBaseUrl}/api/profile`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
      return response.ok;
    } catch (error) {
      return false;
    }
  }

  isTokenExpired(token) {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.exp * 1000 < Date.now();
    } catch {
      return true;
    }
  }

  redirectToLogin() {
    const currentUrl = encodeURIComponent(window.location.href);
    window.location.href = `/login.html?redirect=${currentUrl}`;
  }

  showAuthenticatedContent() {
    document.querySelectorAll('.content-auth-required').forEach(el => {
      el.classList.remove('gated');
    });
  }

  async loadUserProfile() {
    try {
      const token = localStorage.getItem('auth_token');
      const response = await fetch(`${this.apiBaseUrl}/api/profile`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      if (response.ok) {
        const profile = await response.json();
        localStorage.setItem('user_profile', JSON.stringify(profile));
        this.updateUIWithProfile(profile);
      }
    } catch (error) {
      console.error('Failed to load user profile:', error);
    }
  }

  updateUIWithProfile(profile) {
    // Update user name in navigation
    const userNameElements = document.querySelectorAll('.user-name');
    userNameElements.forEach(el => {
      el.textContent = profile.name || profile.email;
    });

    // Update personalized recommendations
    this.loadPersonalizedContent(profile);
  }

  // Public Access Pages
  handlePublicAccess() {
    // Track page view
    this.trackEngagement('public_page_viewed');
    
    // Show competitive advantages
    this.highlightCompetitiveAdvantages();
    
    // Setup lead capture forms
    this.setupLeadCaptureForms();
  }

  // Authentication Methods
  async login(email, password) {
    try {
      const response = await fetch(`${this.apiBaseUrl}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });

      if (response.ok) {
        const data = await response.json();
        localStorage.setItem('auth_token', data.token);
        localStorage.setItem('refresh_token', data.refreshToken);
        localStorage.setItem('user_profile', JSON.stringify(data.user));

        // Track successful login
        this.trackEngagement('user_login', { email });

        // Redirect to original page or dashboard
        const urlParams = new URLSearchParams(window.location.search);
        const redirectUrl = urlParams.get('redirect') || '/auth-academy-dashboard.html';
        window.location.href = redirectUrl;
      } else {
        const error = await response.json();
        throw new Error(error.message || 'Login failed');
      }
    } catch (error) {
      console.error('Login error:', error);
      this.showNotification('❌ Invalid email or password', 'error');
    }
  }

  async register(userData) {
    try {
      const response = await fetch(`${this.apiBaseUrl}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(userData)
      });

      if (response.ok) {
        const data = await response.json();
        
        // Track successful registration
        this.trackEngagement('user_registration', userData);
        
        this.showNotification('✅ Registration successful! Please check your email to verify your account.', 'success');
        
        // Redirect to login after delay
        setTimeout(() => {
          window.location.href = '/login.html';
        }, 2000);
      } else {
        const error = await response.json();
        throw new Error(error.message || 'Registration failed');
      }
    } catch (error) {
      console.error('Registration error:', error);
      this.showNotification('❌ Registration failed. Please try again.', 'error');
    }
  }

  logout() {
    // Clear all stored data
    localStorage.removeItem('auth_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('user_profile');
    
    // Track logout
    this.trackEngagement('user_logout');
    
    // Redirect to homepage
    window.location.href = '/index.html';
  }

  // Utility Methods
  async sendToEmailService({ email, name, company }) {
    // Integration with HubSpot, Mailchimp, or other email services
    try {
      // Example HubSpot integration
      const hubspotData = {
        properties: {
          email,
          firstname: name,
          company,
          lead_source: 'CloudNestle Website',
          lifecycle_stage: 'lead'
        }
      };

      // This would be replaced with actual HubSpot API call
      console.log('Sending to email service:', hubspotData);
      
      // For now, just simulate success
      return Promise.resolve();
    } catch (error) {
      console.error('Email service integration failed:', error);
      // Don't throw error - registration should still work locally
    }
  }

  trackEngagement(event, data = {}) {
    // Analytics tracking (Google Analytics, Mixpanel, etc.)
    try {
      if (typeof gtag !== 'undefined') {
        gtag('event', event, {
          custom_parameter: data,
          page_title: document.title,
          page_location: window.location.href
        });
      }
      
      // Also store locally for competitive intelligence
      const engagementData = {
        event,
        data,
        timestamp: new Date().toISOString(),
        page: window.location.pathname,
        user_agent: navigator.userAgent
      };
      
      const engagementHistory = JSON.parse(localStorage.getItem('engagement_history') || '[]');
      engagementHistory.push(engagementData);
      
      // Keep only last 100 events
      if (engagementHistory.length > 100) {
        engagementHistory.splice(0, engagementHistory.length - 100);
      }
      
      localStorage.setItem('engagement_history', JSON.stringify(engagementHistory));
    } catch (error) {
      console.error('Analytics tracking failed:', error);
    }
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
      <div class="notification-content">
        <span class="notification-message">${message}</span>
        <button class="notification-close">&times;</button>
      </div>
    `;

    document.body.appendChild(notification);

    // Auto-remove after 5 seconds
    setTimeout(() => {
      notification.remove();
    }, 5000);

    // Manual close
    notification.querySelector('.notification-close').addEventListener('click', () => {
      notification.remove();
    });
  }

  isRegistrationExpired(registrationDate) {
    if (!registrationDate) return true;
    
    const registered = new Date(registrationDate);
    const now = new Date();
    const daysSinceRegistration = (now - registered) / (1000 * 60 * 60 * 24);
    
    // Registration expires after 30 days (encourage full account creation)
    return daysSinceRegistration > 30;
  }

  highlightCompetitiveAdvantages() {
    // Dynamically highlight competitive advantages on public pages
    const advantages = [
      'Industry-specific AWS expertise (Education, Retail, SMB)',
      'AI-powered architecture analysis and recommendations',
      'Outcome guarantees with insurance backing',
      'Community of 10,000+ AWS professionals',
      'Proprietary assessment and automation tools'
    ];

    // Add competitive advantage callouts to relevant sections
    const sections = document.querySelectorAll('.competitive-highlight');
    sections.forEach((section, index) => {
      if (advantages[index]) {
        const callout = document.createElement('div');
        callout.className = 'advantage-callout';
        callout.innerHTML = `
          <div class="advantage-icon">🏆</div>
          <div class="advantage-text">${advantages[index]}</div>
        `;
        section.appendChild(callout);
      }
    });
  }

  setupLeadCaptureForms() {
    // Setup lead capture forms on public pages
    const forms = document.querySelectorAll('.lead-capture-form');
    forms.forEach(form => {
      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const formData = new FormData(form);
        const email = formData.get('email');
        const name = formData.get('name');
        
        if (email) {
          await this.captureRegistration({ email, name, company: '' });
        }
      });
    });
  }

  setupEventListeners() {
    // Global event listeners
    document.addEventListener('DOMContentLoaded', () => {
      // Setup logout buttons
      document.querySelectorAll('.logout-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.preventDefault();
          this.logout();
        });
      });

      // Setup login forms
      document.querySelectorAll('.login-form').forEach(form => {
        form.addEventListener('submit', async (e) => {
          e.preventDefault();
          const formData = new FormData(form);
          await this.login(formData.get('email'), formData.get('password'));
        });
      });
    });
  }

  async loadPersonalizedContent(profile) {
    // Load AI-powered personalized recommendations
    try {
      const token = localStorage.getItem('auth_token');
      const response = await fetch(`${this.apiBaseUrl}/api/recommendations`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      if (response.ok) {
        const recommendations = await response.json();
        this.displayPersonalizedRecommendations(recommendations);
      }
    } catch (error) {
      console.error('Failed to load personalized content:', error);
    }
  }

  displayPersonalizedRecommendations(recommendations) {
    const container = document.querySelector('.personalized-recommendations');
    if (container && recommendations.length > 0) {
      container.innerHTML = `
        <h3>Recommended for You</h3>
        <div class="recommendations-grid">
          ${recommendations.map(rec => `
            <div class="recommendation-card">
              <h4>${rec.title}</h4>
              <p>${rec.description}</p>
              <a href="${rec.url}" class="btn btn-outline">Learn More</a>
            </div>
          `).join('')}
        </div>
      `;
    }
  }

  startSpotMonitoring() {
    // Monitor for spot instance interruptions
    if (typeof window !== 'undefined') {
      setInterval(() => {
        // Save current state periodically
        const currentState = {
          page: window.location.pathname,
          timestamp: new Date().toISOString(),
          user_email: localStorage.getItem('user_email'),
          auth_token: localStorage.getItem('auth_token') ? 'present' : 'absent'
        };
        
        localStorage.setItem('last_known_state', JSON.stringify(currentState));
      }, 30000); // Every 30 seconds
    }
  }
}

// Initialize the authentication manager
const authManager = new CloudNestleAuthManager();

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CloudNestleAuthManager;
}

// Global utility functions
window.CloudNestleAuth = {
  login: (email, password) => authManager.login(email, password),
  register: (userData) => authManager.register(userData),
  logout: () => authManager.logout(),
  trackEvent: (event, data) => authManager.trackEngagement(event, data)
};
