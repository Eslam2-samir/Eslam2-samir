import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import { getProfile, previewProfile } from '@/lib/api'
import type { Profile } from '@/types/domain'

const authCooldownKey = 'el-saidy-auth-cooldown'
function enforceAuthCooldown() {
  const until = Number(localStorage.getItem(authCooldownKey) || 0)
  if (until > Date.now()) throw new Error('AUTH_RATE_LIMIT')
}
function noteAuthFailure() {
  const current = Number(localStorage.getItem(authCooldownKey) || 0)
  const remaining = Math.max(1000, current - Date.now())
  localStorage.setItem(authCooldownKey, String(Date.now() + Math.min(30000, Math.max(3000, remaining * 2))))
}

export function useAuth() {
  const [session, setSession] = useState<Session | null>(null)
  const [profile, setProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(true)
  const [accessError, setAccessError] = useState('')
  function applyProfile(nextProfile: Profile | null) {
    if (nextProfile && ['admin', 'staff'].includes(nextProfile.role) && nextProfile.admin_status === 'blocked') { setAccessError('ADMIN_BLOCKED'); setProfile(null); return }
    setAccessError(''); setProfile(nextProfile)
  }

  useEffect(() => {
    let mounted = true
    async function boot() {
      if (!supabase) {
        if (mounted) {
          const role = localStorage.getItem('suezbus-preview-role')
          setProfile(role ? { ...previewProfile, role: role === 'admin' ? 'admin' : 'student' } : null)
          setLoading(false)
        }
        return
      }
      const { data } = await supabase.auth.getSession()
      if (!mounted) return
      setSession(data.session)
      applyProfile(await getProfile(data.session?.user.id))
      setLoading(false)
    }
    void boot()
    if (!supabase) return () => { mounted = false }
    const { data: listener } = supabase.auth.onAuthStateChange(async (_event, nextSession) => {
      setSession(nextSession)
      applyProfile(await getProfile(nextSession?.user.id))
      setLoading(false)
    })
    return () => { mounted = false; listener.subscription.unsubscribe() }
  }, [])

  async function signIn(email: string, password: string) {
    enforceAuthCooldown()
    if (!supabase) {
      const preview = await getProfile()
      if (preview) setProfile({ ...preview, email, role: localStorage.getItem('suezbus-preview-role') === 'admin' ? 'admin' : 'student' })
      return
    }
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) { noteAuthFailure(); throw error }
    localStorage.removeItem(authCooldownKey)
    applyProfile(await getProfile((await supabase.auth.getUser()).data.user?.id))
  }

  async function signUp(values: { email: string; password: string; fullName: string; studentId: string; phone: string; university: string; stationId: string; preferredWeekdays: number[] }) {
    if (!supabase) throw new Error('SUPABASE_NOT_CONFIGURED')
    enforceAuthCooldown()
    const { data, error } = await supabase.auth.signUp({ email: values.email, password: values.password, options: { data: { full_name: values.fullName, student_id: values.studentId, phone: values.phone, university: values.university, default_station_id: values.stationId, preferred_weekdays: values.preferredWeekdays } } })
    if (error) { noteAuthFailure(); throw error }
    localStorage.removeItem(authCooldownKey)
    return data
  }

  async function signOut() {
    if (supabase) await supabase.auth.signOut()
    setSession(null); setProfile(null); setAccessError('')
  }

  async function resetPassword(email: string) {
    if (!supabase) throw new Error('SUPABASE_NOT_CONFIGURED')
    enforceAuthCooldown()
    const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/auth/login` })
    if (error) { noteAuthFailure(); throw error }
    localStorage.removeItem(authCooldownKey)
  }

  return { session, profile, setProfile, loading, accessError, signIn, signUp, signOut, resetPassword, isPreview: !supabase }
}
