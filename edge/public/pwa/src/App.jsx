import { BrowserRouter, Routes, Route, NavLink } from "react-router-dom"
import { ConnectivityProvider, useConnectivity } from "./context/ConnectivityContext"
import TablesScreen from "./screens/TablesScreen"
import OrderScreen from "./screens/OrderScreen"
import StatusScreen from "./screens/StatusScreen"
import KdsScreen from "./screens/KdsScreen"
import "./App.css"

function ConnectivityBadge() {
  const { status, pendingCount } = useConnectivity()
  const map = {
    online:  { label: "En linea",     cls: "badge-green"  },
    offline: { label: "Sin conexion", cls: "badge-red"    },
    syncing: { label: "Sincronizando",cls: "badge-amber"  },
    unknown: { label: "Conectando",   cls: "badge-gray"   },
  }
  const { label, cls } = map[status] || map.unknown
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
      {pendingCount > 0 && <span className={"badge badge-amber"}>{pendingCount} pendientes</span>}
      <span className={"badge " + cls}>{label}</span>
    </div>
  )
}

function Layout() {
  return (
    <div className="app-shell">
      <header className="topbar">
        <span className="topbar-title">ResiliOS POS</span>
        <ConnectivityBadge />
      </header>
      <nav className="bottomnav">
        <NavLink to="/" end>Mesas</NavLink>
        <NavLink to="/status">Estado</NavLink>
        <NavLink to="/kds">Cocina</NavLink>
      </nav>
      <main className="main-content">
        <Routes>
          <Route path="/" element={<TablesScreen />} />
          <Route path="/order/:tableId" element={<OrderScreen />} />
          <Route path="/status" element={<StatusScreen />} />
          <Route path="/kds" element={<KdsScreen />} />
        </Routes>
      </main>
    </div>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <ConnectivityProvider>
        <Layout />
      </ConnectivityProvider>
    </BrowserRouter>
  )
}
