import { useConnectivity } from '../context/ConnectivityContext'

export default function StatusScreen() {
  const { status, nodeStatus, pendingCount, lastSyncAt, refresh } = useConnectivity()

  const labels = {
    online:  'Nodo operativo - en linea',
    offline: 'Sin conexion - modo offline activo',
    syncing: 'Sincronizando con el Cloud...',
    unknown: 'Verificando estado...',
  }

  const colors = { online:'#1D9E75', offline:'#E24B4A', syncing:'#BA7517', unknown:'#888780' }

  const formatSync = (iso) => {
    if (!iso) return 'Nunca'
    const diff = Math.round((Date.now() - new Date(iso)) / 1000)
    if (diff < 60) return 'hace ' + diff + 's'
    if (diff < 3600) return 'hace ' + Math.round(diff/60) + 'min'
    return 'hace ' + Math.round(diff/3600) + 'h'
  }

  return (
    <div>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:14 }}>
        <span style={{ fontSize:14, fontWeight:500 }}>Estado del nodo</span>
        <button className="btn" onClick={refresh} style={{ fontSize:12, padding:'5px 10px' }}>Actualizar</button>
      </div>

      <div className="card" style={{ display:'flex', alignItems:'center', gap:12, marginBottom:12 }}>
        <div style={{ width:10, height:10, borderRadius:'50%', background:colors[status]||colors.unknown, flexShrink:0 }} />
        <div style={{ flex:1 }}>
          <div style={{ fontSize:14, fontWeight:500 }}>{labels[status]}</div>
          <div style={{ fontSize:12, color:'var(--text-muted)' }}>v{nodeStatus?.version||'—'}</div>
        </div>
        <span className={'badge ' + (status==='online'?'badge-green':status==='offline'?'badge-red':'badge-amber')}>{status}</span>
      </div>

      <div className="metric-grid">
        <div className="metric-card">
          <div className="metric-label">Conexion</div>
          <div className={'metric-value ' + (status==='online'?'green':status==='offline'?'red':'amber')}>
            {status==='online'?'En linea':status==='offline'?'Offline':'Syncing'}
          </div>
        </div>
        <div className="metric-card">
          <div className="metric-label">Pendientes sync</div>
          <div className={'metric-value ' + (pendingCount>0?'amber':'green')}>{pendingCount}</div>
        </div>
        <div className="metric-card">
          <div className="metric-label">Ultimo sync</div>
          <div className="metric-value sm">{formatSync(lastSyncAt)}</div>
        </div>
        <div className="metric-card">
          <div className="metric-label">Base de datos</div>
          <div className="metric-value sm">
            {nodeStatus?.system?.db_size_mb ? nodeStatus.system.db_size_mb + ' MB' : '—'}
          </div>
        </div>
      </div>

      {nodeStatus?.restaurant && (
        <div className="card" style={{ marginTop:12 }}>
          <div style={{ fontSize:13, fontWeight:500, color:'var(--text-muted)', marginBottom:8 }}>Restaurante</div>
          <div style={{ fontSize:14, fontWeight:500 }}>{nodeStatus.restaurant.name}</div>
        </div>
      )}
    </div>
  )
}