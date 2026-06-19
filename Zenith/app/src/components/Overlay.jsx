import React, { useState, useEffect, useRef } from 'react';
import Tesseract from 'tesseract.js';
import { Loader2 } from 'lucide-react';

export default function Overlay() {
  const [screenshotUrl, setScreenshotUrl] = useState('');
  const [isMouseDown, setIsMouseDown] = useState(false);
  const [startPos, setStartPos] = useState({ x: 0, y: 0 });
  const [currentPos, setCurrentPos] = useState({ x: 0, y: 0 });
  const [loadingOCR, setLoadingOCR] = useState(false);
  const [ocrProgress, setOcrProgress] = useState(0);

  const containerRef = useRef(null);
  const imgRef = useRef(null);

  // 1. Capture screen on mount
  useEffect(() => {
    const doCapture = async () => {
      try {
        const url = await window.zenithAPI.captureScreen();
        setScreenshotUrl(url);
      } catch (err) {
        console.error("Capture screen error:", err);
      }
    };
    doCapture();

    // Escape key closes overlay
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        window.zenithAPI.closeOverlay();
      }
    };
    window.addEventListener('keydown', handleKeyDown);

    // Listen to shortcut triggered (re-capture)
    const unsubscribe = window.zenithAPI.onShortcutTriggered((newUrl) => {
      setScreenshotUrl(newUrl);
      setIsMouseDown(false);
      setStartPos({ x: 0, y: 0 });
      setCurrentPos({ x: 0, y: 0 });
    });

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      unsubscribe();
    };
  }, []);

  const handleMouseDown = (e) => {
    if (loadingOCR) return;
    setIsMouseDown(true);
    const rect = containerRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    setStartPos({ x, y });
    setCurrentPos({ x, y });
  };

  const handleMouseMove = (e) => {
    if (!isMouseDown || loadingOCR) return;
    const rect = containerRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    setCurrentPos({ x, y });
  };

  const handleMouseUp = async (e) => {
    if (!isMouseDown || loadingOCR) return;
    setIsMouseDown(false);

    const x1 = Math.min(startPos.x, currentPos.x);
    const y1 = Math.min(startPos.y, currentPos.y);
    const width = Math.abs(startPos.x - currentPos.x);
    const height = Math.abs(startPos.y - currentPos.y);

    // Ignore tiny clicks (less than 10px)
    if (width < 10 || height < 10) return;

    setLoadingOCR(true);
    setOcrProgress(0);

    try {
      // 1. Crop image using canvas
      const croppedBase64 = await cropImage(screenshotUrl, x1, y1, width, height);

      // 2. Perform local OCR using Tesseract.js
      let ocrText = "";
      try {
        const result = await Tesseract.recognize(
          croppedBase64,
          'eng',
          {
            logger: (m) => {
              if (m.status === 'recognizing text') {
                setOcrProgress(Math.round(m.progress * 100));
              }
            }
          }
        );
        ocrText = result.data.text;
      } catch (ocrErr) {
        console.error("Tesseract local OCR error:", ocrErr);
      }

      // 3. Detect foreground app process and window title
      const activeApp = await window.zenithAPI.getActiveApp();

      // 4. Open companion card near selection
      // Calculate absolute screen coords of the crop box release point
      const primaryRect = containerRef.current.getBoundingClientRect();
      const screenX = window.screenX + x1 + width;
      const screenY = window.screenY + y1;

      window.zenithAPI.openCard({
        x: screenX,
        y: screenY,
        data: {
          image_base64: croppedBase64.replace(/^data:image\/\w+;base64,/, ""),
          ocr_text: ocrText,
          active_app: activeApp.appName,
          window_title: activeApp.windowTitle,
          x: x1,
          y: y1,
          width,
          height
        }
      });

      // 5. Hide selection overlay
      window.zenithAPI.closeOverlay();
    } catch (err) {
      console.error("Crop/OCR pipeline failure:", err);
      alert("Failed to process selected region.");
      setLoadingOCR(false);
    }
  };

  const cropImage = (src, x, y, w, h) => {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, x, y, w, h, 0, 0, w, h);
        resolve(canvas.toDataURL('image/png'));
      };
      img.onerror = (e) => reject(e);
      img.src = src;
    });
  };

  // Compute selection box dimensions
  const x = Math.min(startPos.x, currentPos.x);
  const y = Math.min(startPos.y, currentPos.y);
  const width = Math.abs(startPos.x - currentPos.x);
  const height = Math.abs(startPos.y - currentPos.y);

  return (
    <div 
      ref={containerRef}
      style={styles.overlayContainer}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
    >
      {/* Background screenshot */}
      {screenshotUrl && (
        <img 
          ref={imgRef}
          src={screenshotUrl} 
          alt="Desktop Capture" 
          style={styles.screenshotImage} 
        />
      )}

      {/* Dim overlay outside the crop region */}
      {!loadingOCR && isMouseDown && width > 0 && height > 0 && (
        <div style={{
          ...styles.dimmer,
          clipPath: `polygon(
            0% 0%, 
            0% 100%, 
            ${x}px 100%, 
            ${x}px ${y}px, 
            ${x + width}px ${y}px, 
            ${x + width}px ${y + height}px, 
            ${x}px ${y + height}px, 
            ${x}px 100%, 
            100% 100%, 
            100% 0%
          )`
        }} />
      )}

      {/* Selector box outline */}
      {!loadingOCR && isMouseDown && width > 0 && height > 0 && (
        <div style={{
          ...styles.selectionBox,
          left: `${x}px`,
          top: `${y}px`,
          width: `${width}px`,
          height: `${height}px`,
        }}>
          <div style={styles.dimensionsBadge}>{Math.round(width)} × {Math.round(height)}</div>
        </div>
      )}

      {/* OCR Loader panel */}
      {loadingOCR && (
        <div style={styles.ocrLoader}>
          <div style={styles.ocrLoaderContent}>
            <Loader2 className="spin-animation" size={28} color="var(--color-primary)" />
            <div style={{ marginTop: '12px', fontWeight: '600' }}>Running Local OCR...</div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>
              {ocrProgress > 0 ? `Analyzing layout: ${ocrProgress}%` : 'Reading characters...'}
            </div>
          </div>
        </div>
      )}

      {/* Instruction tooltip */}
      {!isMouseDown && !loadingOCR && (
        <div style={styles.tooltip}>
          Drag marquee over screen region • Press <kbd style={styles.kbd}>Esc</kbd> to exit
        </div>
      )}
    </div>
  );
}

const styles = {
  overlayContainer: {
    position: 'relative',
    width: '100vw',
    height: '100vh',
    overflow: 'hidden',
    cursor: 'crosshair',
    backgroundColor: 'rgba(0, 0, 0, 0.1)',
  },
  screenshotImage: {
    width: '100%',
    height: '100%',
    objectFit: 'cover',
    pointerEvents: 'none',
  },
  dimmer: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: '100%',
    height: '100%',
    backgroundColor: 'rgba(0, 0, 0, 0.45)',
    pointerEvents: 'none',
  },
  selectionBox: {
    position: 'absolute',
    border: '2px solid var(--color-primary)',
    boxShadow: '0 0 10px rgba(99, 102, 241, 0.3), inset 0 0 10px rgba(99, 102, 241, 0.1)',
    pointerEvents: 'none',
  },
  dimensionsBadge: {
    position: 'absolute',
    bottom: '-24px',
    right: 0,
    background: 'var(--bg-main)',
    color: 'white',
    padding: '2px 6px',
    borderRadius: '4px',
    fontSize: '0.75rem',
    fontWeight: '600',
    border: '1px solid var(--border-subtle)',
  },
  ocrLoader: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: '100%',
    height: '100%',
    background: 'rgba(7, 7, 10, 0.75)',
    backdropFilter: 'blur(8px)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 100,
  },
  ocrLoaderContent: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'rgba(18, 18, 24, 0.9)',
    border: '1px solid var(--border-subtle)',
    borderRadius: '12px',
    padding: '24px 40px',
    boxShadow: '0 10px 30px rgba(0, 0, 0, 0.5)',
  },
  tooltip: {
    position: 'absolute',
    top: '20px',
    left: '50%',
    transform: 'translateX(-50%)',
    background: 'rgba(18, 18, 24, 0.85)',
    backdropFilter: 'blur(12px)',
    border: '1px solid var(--border-subtle)',
    borderRadius: '8px',
    padding: '8px 16px',
    fontSize: '0.85rem',
    color: 'var(--text-main)',
    pointerEvents: 'none',
    boxShadow: '0 4px 12px rgba(0,0,0,0.3)',
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
  },
  kbd: {
    fontFamily: 'var(--font-mono)',
    fontSize: '0.75rem',
    background: 'rgba(0,0,0,0.5)',
    padding: '2px 5px',
    borderRadius: '4px',
    color: 'white',
    border: '1px solid rgba(255,255,255,0.1)',
  }
};
