// src/main.jsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import './App.css'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>
)

// ─────────────────────────────────────────────────────────────────
// src/screens/TablesScreen.jsx
// Re-exportar desde el archivo combinado
// ─────────────────────────────────────────────────────────────────
// INSTRUCCIÓN: Divide TablesAndOrderScreens.jsx en archivos separados:
//
//   src/screens/TablesScreen.jsx  ← exportar TablesScreen (default)
//   src/screens/OrderScreen.jsx   ← exportar OrderScreen (default)
//   src/screens/StatusScreen.jsx  ← exportar StatusScreen (default)
//   src/screens/KdsScreen.jsx     ← exportar KdsScreen (default)
//
// O usa estos imports directos en App.jsx:
//   import TablesScreen from './screens/TablesAndOrderScreens.jsx'
//   import { OrderScreen } from './screens/TablesAndOrderScreens.jsx'
//   import StatusScreen from './screens/StatusAndKdsScreens.jsx'
//   import { default as KdsScreen } from './screens/StatusAndKdsScreens.jsx' (segundo export)
