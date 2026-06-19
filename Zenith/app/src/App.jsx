import React, { useState, useEffect } from 'react';
import Overlay from './components/Overlay';
import ResultCard from './components/ResultCard';
import Settings from './components/Settings';

export default function App() {
  const [mode, setMode] = useState('settings');
  const [paramsData, setParamsData] = useState(null);

  useEffect(() => {
    // Parse query parameters
    const params = new URLSearchParams(window.location.search);
    const currentMode = params.get('mode') || 'settings';
    setMode(currentMode);

    const dataStr = params.get('data');
    if (dataStr) {
      try {
        setParamsData(JSON.parse(decodeURIComponent(dataStr)));
      } catch (e) {
        console.error("Failed to parse query data:", e);
      }
    }
  }, []);

  switch (mode) {
    case 'overlay':
      return <Overlay />;
    case 'card':
      return <ResultCard initialData={paramsData} />;
    case 'settings':
    default:
      return <Settings />;
  }
}
