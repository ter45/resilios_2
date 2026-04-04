// ══════════════════════════════════════════════════════════════════
//  src/context/ConnectivityContext.jsx
//  Detecta el estado online/offline del nodo Edge y lo expone
//  globalmente. El resto de la app reacciona a este contexto.
// ══════════════════════════════════════════════════════════════════

import { createContext, useContext, useEffect, useState, useCallback } from 'react'
import { api } from '../api/client'

const ConnectivityContext = createContext(null)

export function ConnectivityProvider({ children }) {
  const [status, setStatus]       = useState('unknown')   // online | offline | syncing | unknown
  const [nodeStatus, setNodeStatus] = useState(null)
  const [pendingCount, setPendingCount] = useState(0)
  const [lastSyncAt, setLastSyncAt]     = useState(null)

  const checkStatus = useCallback(async () => {
    try {
      const { data } = await api.getStatus()
      setStatus(data.connectivity.status === 'synced' ? 'online' : data.connectivity.status)
      setNodeStatus(data)
      setPendingCount(data.queue.pending_count)
      setLastSyncAt(data.connectivity.last_sync_at)
    } catch {
      setStatus('offline')
      setNodeStatus(null)
    }
  }, [])

  useEffect(() => {
    checkStatus()
    const interval = setInterval(checkStatus, 15_000)  // cada 15s
    return () => clearInterval(interval)
  }, [checkStatus])

  // Detectar cambios de red del navegador también
  useEffect(() => {
    const handleOnline  = () => checkStatus()
    const handleOffline = () => setStatus('offline')
    window.addEventListener('online',  handleOnline)
    window.addEventListener('offline', handleOffline)
    return () => {
      window.removeEventListener('online',  handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [checkStatus])

  return (
    <ConnectivityContext.Provider value={{
      status, nodeStatus, pendingCount, lastSyncAt, refresh: checkStatus
    }}>
      {children}
    </ConnectivityContext.Provider>
  )
}

export const useConnectivity = () => useContext(ConnectivityContext)
