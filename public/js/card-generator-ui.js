/**
 * Character Card Generator UI
 *
 * UI components and logic for the character card generation workflow
 */

class CardGeneratorUI {
  constructor() {
    this.state = {
      selectedLog: null,
      parsedData: null,
      uploadedImage: null,
      parserConfig: {
        mode: 'default',
        includeTags: [],
        excludeTags: [],
      },
    };

    this.apiBase = window.location.origin;
  }

  /**
   * Initialize the UI
   */
  init() {
    this.setupEventListeners();
    this.loadAvailableLogs();
  }

  /**
   * Setup event listeners
   */
  setupEventListeners() {
    // Step 2: Parse button
    const parseBtn = document.getElementById('parseForCardBtn');
    if (parseBtn) {
      parseBtn.onclick = () => this.handleParse();
    }

    // Step 4: Image upload
    const imageInput = document.getElementById('cardImageUpload');
    if (imageInput) {
      imageInput.onchange = (e) => this.handleImageUpload(e);
    }

    // Step 5: Generate button
    const generateBtn = document.getElementById('generateCardBtn');
    if (generateBtn) {
      generateBtn.onclick = () => this.handleGenerate();
    }

    // Parser mode toggles
    document.querySelectorAll('input[name="card_parser_mode"]').forEach(radio => {
      radio.onchange = (e) => {
        this.state.parserConfig.mode = e.target.value;
        this.updateParserUI();
      };
    });
  }

  /**
   * Load available logs from API
   */
  async loadAvailableLogs() {
    try {
      const response = await fetch(`${this.apiBase}/logs`);
      const data = await response.json();

      const selector = document.getElementById('cardLogSelector');
      if (!selector) return;

      selector.innerHTML = '<option value="">Select a log...</option>';

      (data.logs || []).forEach(logName => {
        const option = document.createElement('option');
        option.value = logName;
        option.textContent = logName;
        selector.appendChild(option);
      });

      selector.onchange = (e) => {
        this.state.selectedLog = e.target.value;
      };
    } catch (error) {
      console.error('Failed to load logs:', error);
      this.showNotification('Failed to load logs', 'error');
    }
  }

  /**
   * Handle parse button click
   */
  async handleParse() {
    if (!this.state.selectedLog) {
      this.showNotification('Please select a log first', 'warning');
      return;
    }

    const parseBtn = document.getElementById('parseForCardBtn');
    const previewArea = document.getElementById('cardPreview');

    try {
      // Show loading
      if (parseBtn) parseBtn.disabled = true;
      if (previewArea) previewArea.value = 'Parsing...';

      // Fetch log data
      const logResponse = await fetch(`${this.apiBase}/logs/${encodeURIComponent(this.state.selectedLog)}`);
      const logData = await logResponse.json();

      // Parse with current config
      const parseResponse = await fetch(`${this.apiBase}/api/parse`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: logData.messages,
          parserMode: this.state.parserConfig.mode,
          includeTags: this.state.parserConfig.includeTags,
          excludeTags: this.state.parserConfig.excludeTags,
        }),
      });

      this.state.parsedData = await parseResponse.json();

      // Update preview
      if (previewArea) {
        previewArea.value = this.state.parsedData.content;
      }

      // Update character name field
      const nameInput = document.getElementById('cardCharacterName');
      if (nameInput) {
        nameInput.value = this.state.parsedData.characterName || 'Character';
      }

      this.showNotification('Parsed successfully!', 'success');
      this.scrollToStep(3);
    } catch (error) {
      console.error('Parse error:', error);
      this.showNotification('Parse failed: ' + error.message, 'error');
      if (previewArea) previewArea.value = '';
    } finally {
      if (parseBtn) parseBtn.disabled = false;
    }
  }

  /**
   * Handle image upload
   */
  handleImageUpload(event) {
    const file = event.target.files[0];

    if (!file) return;

    if (!file.type.startsWith('image/png')) {
      this.showNotification('Please upload a PNG image', 'warning');
      return;
    }

    this.state.uploadedImage = file;

    // Show preview
    const preview = document.getElementById('cardImagePreview');
    if (preview) {
      const reader = new FileReader();
      reader.onload = (e) => {
        preview.innerHTML = `<img src="${e.target.result}" alt="Character" style="max-width: 300px; border-radius: 8px;">`;
      };
      reader.readAsDataURL(file);
    }

    this.scrollToStep(5);
  }

  /**
   * Handle generate button click
   */
  async handleGenerate() {
    if (!this.state.parsedData) {
      this.showNotification('Please parse a log first', 'warning');
      return;
    }

    if (!this.state.uploadedImage) {
      this.showNotification('Please upload a character image', 'warning');
      return;
    }

    const generateBtn = document.getElementById('generateCardBtn');

    try {
      if (generateBtn) {
        generateBtn.disabled = true;
        generateBtn.textContent = 'Generating...';
      }

      // Get form values
      const name = document.getElementById('cardCharacterName')?.value || this.state.parsedData.characterName;
      const creator = document.getElementById('cardCreator')?.value || 'Scrapitor';
      const tags = document.getElementById('cardTags')?.value.split(',').map(t => t.trim()).filter(Boolean) || [];

      // Parse content into sections
      const sections = CharacterCardGenerator.parseContent(
        this.state.parsedData.content,
        this.state.parsedData.metadata
      );

      // Generate character card
      await CharacterCardGenerator.generateAndDownload(this.state.uploadedImage, {
        name,
        description: sections.description,
        personality: sections.personality,
        scenario: sections.scenario,
        firstMessage: sections.firstMessage,
        tags,
        creator,
      });

      this.showNotification('Character card generated!', 'success');
    } catch (error) {
      console.error('Generation error:', error);
      this.showNotification('Generation failed: ' + error.message, 'error');
    } finally {
      if (generateBtn) {
        generateBtn.disabled = false;
        generateBtn.textContent = 'Generate & Download';
      }
    }
  }

  /**
   * Update parser UI based on mode
   */
  updateParserUI() {
    const customControls = document.getElementById('cardTagControls');
    if (customControls) {
      customControls.style.display = this.state.parserConfig.mode === 'custom' ? 'block' : 'none';
    }
  }

  /**
   * Scroll to workflow step
   */
  scrollToStep(stepNumber) {
    const step = document.getElementById(`cardStep${stepNumber}`);
    if (step) {
      step.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  }

  /**
   * Show notification
   */
  showNotification(message, type = 'info') {
    // Reuse existing notification system if available
    if (window.notifications) {
      window.notifications.show(message, type);
    } else {
      // Fallback to console
      console.log(`[${type}] ${message}`);
    }
  }
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
  const cardUI = new CardGeneratorUI();
  cardUI.init();
  window.cardGeneratorUI = cardUI;
});
