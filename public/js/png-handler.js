/**
 * PNG Handler
 *
 * Pure JavaScript PNG metadata handler for embedding Character Card data
 * in PNG images using tEXt chunks.
 *
 * Based on PNG specification: http://www.libpng.org/pub/png/spec/1.2/PNG-Structure.html
 */

class PNGHandler {
  /**
   * Add a tEXt chunk to a PNG file
   *
   * @param {Blob|File} imageBlob - PNG image file
   * @param {string} keyword - Chunk keyword (e.g., "chara")
   * @param {string} text - Text to embed
   * @returns {Promise<Blob>} Modified PNG blob
   */
  static async addTextChunk(imageBlob, keyword, text) {
    // Read image as array buffer
    const arrayBuffer = await imageBlob.arrayBuffer();
    const dataView = new DataView(arrayBuffer);

    // Verify PNG signature
    if (!this.isPNG(dataView)) {
      throw new Error('Invalid PNG file');
    }

    // Parse all chunks
    const chunks = this.parseChunks(dataView);

    // Create new tEXt chunk
    const textChunk = this.createTextChunk(keyword, text);

    // Insert before IEND chunk (last chunk)
    chunks.splice(chunks.length - 1, 0, textChunk);

    // Reassemble PNG
    return this.assembleChunks(chunks);
  }

  /**
   * Read tEXt chunk from PNG
   *
   * @param {Blob|File} imageBlob - PNG image file
   * @param {string} keyword - Chunk keyword to find
   * @returns {Promise<string|null>} Text content or null if not found
   */
  static async readTextChunk(imageBlob, keyword) {
    const arrayBuffer = await imageBlob.arrayBuffer();
    const dataView = new DataView(arrayBuffer);

    if (!this.isPNG(dataView)) {
      throw new Error('Invalid PNG file');
    }

    const chunks = this.parseChunks(dataView);

    for (const chunk of chunks) {
      if (chunk.type === 'tEXt') {
        const { keyword: chunkKeyword, text } = this.parseTextChunk(chunk.data);
        if (chunkKeyword === keyword) {
          return text;
        }
      }
    }

    return null;
  }

  /**
   * Check if file is a valid PNG
   */
  static isPNG(dataView) {
    // PNG signature: 137 80 78 71 13 10 26 10
    return (
      dataView.getUint8(0) === 137 &&
      dataView.getUint8(1) === 80 &&
      dataView.getUint8(2) === 78 &&
      dataView.getUint8(3) === 71 &&
      dataView.getUint8(4) === 13 &&
      dataView.getUint8(5) === 10 &&
      dataView.getUint8(6) === 26 &&
      dataView.getUint8(7) === 10
    );
  }

  /**
   * Parse PNG chunks
   */
  static parseChunks(dataView) {
    const chunks = [];
    let offset = 8; // Skip PNG signature

    while (offset < dataView.byteLength) {
      // Read chunk length (4 bytes)
      const length = dataView.getUint32(offset);
      offset += 4;

      // Read chunk type (4 bytes)
      const typeBytes = new Uint8Array(dataView.buffer, offset, 4);
      const type = String.fromCharCode(...typeBytes);
      offset += 4;

      // Read chunk data
      const data = new Uint8Array(dataView.buffer, offset, length);
      offset += length;

      // Read CRC (4 bytes)
      const crc = dataView.getUint32(offset);
      offset += 4;

      chunks.push({ type, data: new Uint8Array(data), crc });

      // Stop at IEND
      if (type === 'IEND') break;
    }

    return chunks;
  }

  /**
   * Create a tEXt chunk
   *
   * Format: keyword\0text
   */
  static createTextChunk(keyword, text) {
    const keywordBytes = new TextEncoder().encode(keyword);
    const textBytes = new TextEncoder().encode(text);

    // Data: keyword + null byte + text
    const data = new Uint8Array(keywordBytes.length + 1 + textBytes.length);
    data.set(keywordBytes, 0);
    data[keywordBytes.length] = 0; // Null separator
    data.set(textBytes, keywordBytes.length + 1);

    // Calculate CRC
    const typeBytes = new TextEncoder().encode('tEXt');
    const crc = this.calculateCRC(typeBytes, data);

    return { type: 'tEXt', data, crc };
  }

  /**
   * Parse tEXt chunk data
   */
  static parseTextChunk(data) {
    // Find null separator
    let nullIndex = -1;
    for (let i = 0; i < data.length; i++) {
      if (data[i] === 0) {
        nullIndex = i;
        break;
      }
    }

    if (nullIndex === -1) {
      throw new Error('Invalid tEXt chunk: no null separator');
    }

    const keyword = new TextDecoder().decode(data.slice(0, nullIndex));
    const text = new TextDecoder().decode(data.slice(nullIndex + 1));

    return { keyword, text };
  }

  /**
   * Reassemble PNG from chunks
   */
  static assembleChunks(chunks) {
    // Calculate total size
    let totalSize = 8; // PNG signature
    for (const chunk of chunks) {
      totalSize += 4 + 4 + chunk.data.length + 4; // length + type + data + crc
    }

    // Create buffer
    const buffer = new ArrayBuffer(totalSize);
    const view = new DataView(buffer);
    const bytes = new Uint8Array(buffer);

    // Write PNG signature
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    signature.forEach((byte, i) => view.setUint8(i, byte));

    let offset = 8;

    // Write chunks
    for (const chunk of chunks) {
      // Length
      view.setUint32(offset, chunk.data.length);
      offset += 4;

      // Type
      const typeBytes = new TextEncoder().encode(chunk.type);
      bytes.set(typeBytes, offset);
      offset += 4;

      // Data
      bytes.set(chunk.data, offset);
      offset += chunk.data.length;

      // CRC
      view.setUint32(offset, chunk.crc);
      offset += 4;
    }

    return new Blob([buffer], { type: 'image/png' });
  }

  /**
   * Calculate CRC32 for PNG chunk
   *
   * Based on PNG specification CRC algorithm
   */
  static calculateCRC(typeBytes, dataBytes) {
    const crcTable = this.makeCRCTable();
    let crc = 0xffffffff;

    // Process type bytes
    for (let i = 0; i < typeBytes.length; i++) {
      crc = crcTable[(crc ^ typeBytes[i]) & 0xff] ^ (crc >>> 8);
    }

    // Process data bytes
    for (let i = 0; i < dataBytes.length; i++) {
      crc = crcTable[(crc ^ dataBytes[i]) & 0xff] ^ (crc >>> 8);
    }

    return crc ^ 0xffffffff;
  }

  /**
   * Generate CRC32 lookup table
   */
  static makeCRCTable() {
    if (this._crcTable) return this._crcTable;

    const table = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) {
        c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      }
      table[n] = c;
    }

    this._crcTable = table;
    return table;
  }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = PNGHandler;
}
