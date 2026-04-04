import { useEffect, useState, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { api } from '../api/client'

export default function OrderScreen() {
  const { tableId } = useParams()
  const navigate    = useNavigate()
  const [table,   setTable]   = useState(null)
  const [menu,    setMenu]    = useState([])
  const [order,   setOrder]   = useState(null)
  const [items,   setItems]   = useState([])
  const [loading, setLoading] = useState(true)
  const [saving,  setSaving]  = useState(false)
  const [error,   setError]   = useState(null)

  const load = useCallback(async () => {
    try {
      const [tableRes, menuRes, ordersRes] = await Promise.all([
        api.getTable(tableId), api.getMenu(), api.getOrders()
      ])
      setTable(tableRes.data)
      setMenu(menuRes.data)
      const existing = ordersRes.data.find(o => o.table.id === tableId)
      if (existing) {
        const detail = await api.getOrder(existing.id)
        setOrder(detail.data)
        setItems(detail.data.items.map(i => ({
          id: i.id, product_id: i.product_id, name: i.product_name,
          price: parseFloat(i.unit_price), qty: i.quantity, notes: i.notes
        })))
      }
    } catch (e) { setError(e.message) }
    finally     { setLoading(false) }
  }, [tableId])

  useEffect(() => { load() }, [load])

  const addProduct = (p) => setItems(prev => {
    const ex = prev.find(i => i.product_id === p.id)
    if (ex) return prev.map(i => i.product_id === p.id ? { ...i, qty: i.qty + 1 } : i)
    return [...prev, { product_id: p.id, name: p.name, price: parseFloat(p.price), qty: 1, notes: '' }]
  })

  const changeQty = (pid, d) => setItems(prev =>
    prev.map(i => i.product_id === pid ? { ...i, qty: i.qty + d } : i).filter(i => i.qty > 0)
  )

  const subtotal = items.reduce((s, i) => s + i.price * i.qty, 0)
  const tax      = subtotal * 0.19
  const total    = subtotal + tax

  const handleConfirm = async () => {
    if (!items.length) return
    setSaving(true)
    try {
      if (order) {
        for (const item of items.filter(i => !i.id))
          await api.addItem(order.id, { product_id: item.product_id, quantity: item.qty })
      } else {
        await api.createOrder({ table_id: tableId, waiter_name: 'Mesero',
          items: items.map(i => ({ product_id: i.product_id, quantity: i.qty })) })
      }
      navigate('/')
    } catch (e) { setError(e.message) }
    finally     { setSaving(false) }
  }

  const handleClose = async () => {
    if (!order) return
    setSaving(true)
    try { await api.closeOrder(order.id); navigate('/') }
    catch (e) { setError(e.message); setSaving(false) }
  }

  if (loading) return <div className="loading">Cargando...</div>

  return (
    <div>
      <div style={{ display:'flex', alignItems:'center', gap:8, marginBottom:12 }}>
        <button className="btn" onClick={() => navigate('/')} style={{ fontSize:12, padding:'5px 10px' }}>← Mesas</button>
        <span style={{ fontSize:15, fontWeight:500 }}>Mesa {table?.number}</span>
        {order && <span className="badge badge-purple">Pedido abierto</span>}
      </div>
      {error && <div className="error-msg">{error}</div>}
      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:12 }}>
        <div className="card">
          <div style={{ fontSize:13, fontWeight:500, color:'var(--text-muted)', marginBottom:10 }}>Menu</div>
          {menu.map(cat => (
            <div key={cat.id} style={{ marginBottom:12 }}>
              <div style={{ fontSize:11, fontWeight:500, color:'var(--text-muted)', marginBottom:6, textTransform:'uppercase' }}>{cat.name}</div>
              {cat.products.map(p => (
                <button key={p.id} onClick={() => addProduct(p)}
                  style={{ width:'100%', textAlign:'left', background:'var(--gray-light)', border:'0.5px solid var(--border)', borderRadius:8, padding:'8px 10px', marginBottom:6, cursor:'pointer', display:'flex', justifyContent:'space-between', fontSize:13 }}>
                  <span>{p.name}</span>
                  <span style={{ color:'var(--purple)', fontWeight:500 }}>${Number(p.price).toLocaleString('es-CO')}</span>
                </button>
              ))}
            </div>
          ))}
        </div>
        <div className="card" style={{ display:'flex', flexDirection:'column' }}>
          <div style={{ fontSize:13, fontWeight:500, color:'var(--text-muted)', marginBottom:10 }}>Pedido actual</div>
          {items.length === 0
            ? <div className="empty-state">Agrega productos</div>
            : <div style={{ flex:1 }}>
                {items.map(item => (
                  <div key={item.product_id} style={{ display:'flex', justifyContent:'space-between', alignItems:'center', padding:'7px 0', borderBottom:'0.5px solid var(--border)', fontSize:13 }}>
                    <div>
                      <div>{item.name}</div>
                      <div style={{ fontSize:12, color:'var(--text-muted)' }}>${Number(item.price).toLocaleString('es-CO')} c/u</div>
                    </div>
                    <div style={{ display:'flex', alignItems:'center', gap:6 }}>
                      <button onClick={() => changeQty(item.product_id, -1)} style={{ width:24, height:24, borderRadius:'50%', border:'0.5px solid var(--border)', background:'transparent', cursor:'pointer', fontSize:16 }}>-</button>
                      <span style={{ minWidth:18, textAlign:'center' }}>{item.qty}</span>
                      <button onClick={() => changeQty(item.product_id, +1)} style={{ width:24, height:24, borderRadius:'50%', border:'0.5px solid var(--border)', background:'transparent', cursor:'pointer', fontSize:16 }}>+</button>
                    </div>
                  </div>
                ))}
                <div style={{ marginTop:10, paddingTop:10, borderTop:'0.5px solid var(--border)' }}>
                  <div style={{ display:'flex', justifyContent:'space-between', fontSize:13, color:'var(--text-muted)', marginBottom:4 }}>
                    <span>Subtotal</span><span>${subtotal.toLocaleString('es-CO',{maximumFractionDigits:0})}</span>
                  </div>
                  <div style={{ display:'flex', justifyContent:'space-between', fontSize:13, color:'var(--text-muted)', marginBottom:8 }}>
                    <span>IVA 19%</span><span>${tax.toLocaleString('es-CO',{maximumFractionDigits:0})}</span>
                  </div>
                  <div style={{ display:'flex', justifyContent:'space-between', fontSize:15, fontWeight:500 }}>
                    <span>Total</span><span style={{ color:'var(--purple)' }}>${total.toLocaleString('es-CO',{maximumFractionDigits:0})}</span>
                  </div>
                </div>
              </div>
          }
          <div style={{ display:'flex', flexDirection:'column', gap:8, marginTop:12 }}>
            <button className="btn btn-primary btn-full" onClick={handleConfirm} disabled={saving || !items.length}>
              {saving ? 'Guardando...' : order ? 'Agregar al pedido' : 'Confirmar pedido'}
            </button>
            {order && <button className="btn btn-success btn-full" onClick={handleClose} disabled={saving}>Cerrar y cobrar</button>}
          </div>
        </div>
      </div>
    </div>
  )
}