import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../api/client'

const STATUS_MAP = {
  available: { label: 'Libre',     cls: 'badge-green',  bg: '#E1F5EE', border: '#9FE1CB' },
  occupied:  { label: 'Ocupada',   cls: 'badge-purple', bg: '#EEEDFE', border: '#AFA9EC' },
  reserved:  { label: 'Reservada', cls: 'badge-amber',  bg: '#FAEEDA', border: '#FAC775' },
}

export default function TablesScreen() {
  const [tables,  setTables]  = useState([])
  const [loading, setLoading] = useState(true)
  const [error,   setError]   = useState(null)
  const navigate = useNavigate()

  const load = async () => {
    try {
      setError(null)
      const { data } = await api.getTables()
      setTables(data)
    } catch (e) { setError(e.message) }
    finally     { setLoading(false) }
  }

  useEffect(() => { load() }, [])

  if (loading) return <div className="loading">Cargando mesas...</div>

  const occupied  = tables.filter(t => t.status === 'occupied').length
  const available = tables.filter(t => t.status === 'available').length

  return (
    <div>
      {error && <div className="error-msg">{error}</div>}
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:12 }}>
        <span style={{ fontSize:13, color:'var(--text-muted)' }}>
          {tables.length} mesas · {occupied} ocupadas · {available} libres
        </span>
        <button className="btn" onClick={load} style={{ fontSize:12, padding:'5px 10px' }}>Actualizar</button>
      </div>
      <div style={{ display:'grid', gridTemplateColumns:'repeat(3, minmax(0,1fr))', gap:10 }}>
        {tables.map(table => {
          const s = STATUS_MAP[table.status] || STATUS_MAP.available
          return (
            <div key={table.id} className="card"
              onClick={() => navigate('/order/' + table.id)}
              style={{ cursor:'pointer', borderColor:s.border, background:s.bg }}>
              <div style={{ fontSize:26, fontWeight:500, marginBottom:2 }}>{table.number}</div>
              {table.label && (
                <div style={{ fontSize:12, color:'var(--text-muted)', marginBottom:4 }}>{table.label}</div>
              )}
              {table.current_order && (
                <div style={{ fontSize:13, fontWeight:500, color:'var(--purple)', marginBottom:6 }}>
                  ${Number(table.current_order.total).toLocaleString('es-CO')}
                </div>
              )}
              <span className={'badge ' + s.cls}>{s.label}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}