import { useEffect, useState, useCallback } from 'react'
import { api } from '../api/client'

const ITEM_STATUS = {
  pending:   { label: 'Pendiente',  cls: 'badge-gray'   },
  preparing: { label: 'Preparando', cls: 'badge-amber'  },
  ready:     { label: 'Listo',      cls: 'badge-green'  },
  served:    { label: 'Servido',    cls: 'badge-purple' },
}

export default function KdsScreen() {
  const [orders,  setOrders]  = useState([])
  const [loading, setLoading] = useState(true)
  const [error,   setError]   = useState(null)

  const load = useCallback(async () => {
    try {
      setError(null)
      const { data } = await api.getKdsOrders()
      setOrders(data)
    } catch (e) { setError(e.message) }
    finally     { setLoading(false) }
  }, [])

  useEffect(() => {
    load()
    const t = setInterval(load, 8000)
    return () => clearInterval(t)
  }, [load])

  const markOrderReady = async (id) => {
    try { await api.markOrderReady(id); load() }
    catch (e) { setError(e.message) }
  }

  const markItemReady = async (id) => {
    try { await api.markItemReady(id); load() }
    catch (e) { setError(e.message) }
  }

  if (loading && !orders.length) return <div className="loading">Cargando cocina...</div>

  const urgent = orders.filter(o => o.waiting_minutes >= 15)

  return (
    <div>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:12 }}>
        <span style={{ fontSize:13, color:'var(--text-muted)' }}>{orders.length} pedidos activos</span>
        <div style={{ display:'flex', gap:8 }}>
          {urgent.length > 0 && (
            <span className="badge badge-red">{urgent.length} urgente{urgent.length !== 1 ? 's' : ''}</span>
          )}
          <button className="btn" onClick={load} style={{ fontSize:12, padding:'5px 10px' }}>Actualizar</button>
        </div>
      </div>

      {error && <div className="error-msg">{error}</div>}

      {orders.length === 0
        ? <div className="empty-state">No hay pedidos activos en cocina</div>
        : <div style={{ display:'grid', gridTemplateColumns:'repeat(2, minmax(0,1fr))', gap:10 }}>
            {orders.map(o => {
              const isUrgent = o.waiting_minutes >= 15
              return (
                <div key={o.id} className="card" style={{
                  borderColor: isUrgent ? '#F0997B' : 'var(--border)',
                  background:  isUrgent ? '#FAECE7' : 'var(--surface)',
                }}>
                  <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:10 }}>
                    <span style={{ fontSize:18, fontWeight:500 }}>Mesa {o.table_number}</span>
                    <span style={{ fontSize:13, fontWeight:500, color: isUrgent ? '#993C1D' : 'var(--text-muted)' }}>
                      {o.waiting_minutes} min
                    </span>
                  </div>
                  {o.items.map(item => {
                    const s = ITEM_STATUS[item.status] || ITEM_STATUS.pending
                    return (
                      <div key={item.id} style={{ display:'flex', justifyContent:'space-between', alignItems:'center', padding:'6px 0', borderBottom:'0.5px solid var(--border)', fontSize:13 }}>
                        <div>
                          <div>
                            {item.product_name}
                            {item.quantity > 1 && <span style={{ color:'var(--purple)', marginLeft:4 }}>x{item.quantity}</span>}
                          </div>
                          {item.notes && <div style={{ fontSize:11, color:'var(--text-muted)' }}>{item.notes}</div>}
                        </div>
                        <div style={{ display:'flex', alignItems:'center', gap:6 }}>
                          <span className={'badge ' + s.cls}>{s.label}</span>
                          {(item.status === 'pending' || item.status === 'preparing') && (
                            <button onClick={() => markItemReady(item.id)} style={{
                              fontSize:11, padding:'3px 8px', borderRadius:8,
                              border:'0.5px solid #9FE1CB', background:'#E1F5EE',
                              color:'#0F6E56', cursor:'pointer', fontWeight:500,
                            }}>Listo</button>
                          )}
                        </div>
                      </div>
                    )
                  })}
                  <button className="btn btn-success btn-full" onClick={() => markOrderReady(o.id)} style={{ marginTop:10 }}>
                    Todo listo - Mesa {o.table_number}
                  </button>
                </div>
              )
            })}
          </div>
      }
    </div>
  )
}