import { supabase, supabaseConfigured } from './supabase'
import type { AppNotification, Booking, BookingBatchInput, BookingChangeRequest, BookingHours, BookingStatus, DepartureTime, DashboardStats, Profile, SecurityEvent, Station, Subscription } from '@/types/domain'

const stationsAr = ['لعوايد', 'المثلث', 'ابو الحسن', 'اول السور', 'شارع الترعه', 'قصر الشوق', 'براديس', 'البان فرحه', 'شارع ناصر', 'الكابنون', 'الاستقامه', 'كليه طب', 'الإسعاف', 'الدمياطي', 'الجامع الكبير', 'شارع عثمان', 'شبراوى', 'اول نافع', 'شيخ البلد', 'المجمع الطبي', 'نبى الله', 'لفظ الجلاله', 'الحريه', 'النهضه', 'ساندبيتش', 'مارينا وادي دجله', 'دولفين', 'جولدن كوست', 'مونت الجلاله']
const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10)
const today = new Date().toISOString().slice(0, 10)

export const previewMode = !supabaseConfigured
export let previewStations: Station[] = stationsAr.map((name_ar, index) => ({ id: `station-${index + 1}`, name_ar, name_en: null, sort_order: index + 1, is_active: true }))
export let previewTimes: DepartureTime[] = [{ id: 'time-0900', time: '09:00:00', label: '09:00', sort_order: 1, is_active: true }, { id: 'time-1000', time: '10:00:00', label: '10:00', sort_order: 2, is_active: true }]
export const previewProfile: Profile = { id: 'preview-student', full_name: 'أحمد سامي', student_id: 'ST-2026-0142', email: 'ahmed@example.com', phone: '01012345678', default_station_id: previewStations[0].id, role: 'student', account_status: 'approved', admin_status: 'active', university: 'جامعة الجلالة', approved_at: new Date().toISOString(), preferred_weekdays: [0, 1, 2, 3, 4, 5, 6] }
export const previewSubscription: Subscription = { id: 'preview-subscription', profile_id: previewProfile.id, start_date: new Date(Date.now() - 12 * 86400000).toISOString().slice(0, 10), end_date: new Date(Date.now() + 18 * 86400000).toISOString().slice(0, 10), status: 'active' }
export const previewBookings: Booking[] = [
  { id: 'booking-1', profile_id: previewProfile.id, station_id: previewStations[0].id, trip_id: null, service_date: today, departure_time: '09:00', status: 'confirmed', booking_batch_id: 'batch-preview-1', station: previewStations[0], profile: { full_name: previewProfile.full_name, student_id: previewProfile.student_id, phone: previewProfile.phone } },
  { id: 'booking-2', profile_id: previewProfile.id, station_id: previewStations[4].id, trip_id: null, service_date: today, departure_time: '09:00', status: 'confirmed', booking_batch_id: 'batch-preview-2', station: previewStations[4], profile: { full_name: previewProfile.full_name, student_id: previewProfile.student_id, phone: previewProfile.phone } },
]
export const previewRequests: BookingChangeRequest[] = [{ id: 'request-preview-1', profile_id: 'student-2', requested_date: new Date(Date.now() + 5 * 86400000).toISOString().slice(0, 10), station_id: previewStations[4].id, departure_time_id: previewTimes[0].id, reason: 'موعد عملي تغير هذا الأسبوع', status: 'pending', reviewed_at: null, profile: { full_name: 'مريم علي', student_id: 'ST-2026-0134', phone: '01098765432' }, station: previewStations[4], departure_time: previewTimes[0] }]
export let previewSecurityEvents: SecurityEvent[] = []
export let previewStudents: Profile[] = [previewProfile, { ...previewProfile, id: 'student-2', full_name: 'مريم علي', student_id: 'ST-2026-0134', email: 'maryam@example.com', phone: '01098765432', default_station_id: previewStations[4].id, account_status: 'pending', approved_at: null }, { ...previewProfile, id: 'student-3', full_name: 'عمر حسن', student_id: 'ST-2026-0101', email: 'omar@example.com', phone: '01055554444', default_station_id: previewStations[8].id, account_status: 'suspended', approved_at: null }]
export let previewAdminProfiles: Profile[] = [{ ...previewProfile, id: 'preview-student', full_name: 'أحمد المدير', email: 'admin@example.com', student_id: 'ADMIN-001', role: 'admin', admin_status: 'active' }, { ...previewProfile, id: 'admin-2', full_name: 'محمود المشرف', email: 'staff@example.com', student_id: 'ADMIN-002', role: 'staff', admin_status: 'active' }]
export let previewBookingHours: BookingHours = { openTime: '08:00', closeTime: '22:00' }

function requireClient() { if (!supabase) throw new Error('SUPABASE_NOT_CONFIGURED'); return supabase }

export async function listActiveStations(): Promise<Station[]> {
  if (previewMode) return previewStations.filter((station) => station.is_active).map((station) => ({ ...station }))
  const { data, error } = await requireClient().from('stations').select('id,name_ar,name_en,sort_order,is_active').eq('is_active', true).order('sort_order')
  if (error) throw error
  return data as Station[]
}

export async function listDepartureTimes(): Promise<DepartureTime[]> {
  if (previewMode) return previewTimes.filter((time) => time.is_active).map((time) => ({ ...time }))
  const { data, error } = await requireClient().from('departure_times').select('id,time,label,sort_order,is_active').eq('is_active', true).order('sort_order')
  if (error) throw error
  return data as DepartureTime[]
}

export async function getProfile(userId?: string): Promise<Profile | null> {
  if (previewMode) return previewProfile
  if (!userId) return null
  const { data, error } = await requireClient().from('profiles').select('*').eq('id', userId).maybeSingle()
  if (error) throw error
  return data as Profile | null
}

export async function getBookingHours(): Promise<BookingHours> {
  if (previewMode) return { ...previewBookingHours }
  const { data, error } = await requireClient().rpc('get_booking_hours')
  if (error) return { openTime: '08:00', closeTime: '22:00' }
  return data as BookingHours
}

export async function adminUpdateBookingHours(hours: BookingHours): Promise<void> {
  if (previewMode) { previewBookingHours = { ...hours }; return }
  const { error } = await requireClient().rpc('admin_update_booking_hours', { p_open_time: hours.openTime, p_close_time: hours.closeTime })
  if (error) throw error
}

export async function getSubscription(userId?: string): Promise<Subscription | null> {
  if (previewMode) return previewSubscription
  if (!userId) return null
  const { data, error } = await requireClient().from('subscriptions').select('*').eq('profile_id', userId).order('end_date', { ascending: false }).limit(1).maybeSingle()
  if (error) throw error
  return data as Subscription | null
}

export async function listBookings(userId?: string, admin = false): Promise<Booking[]> {
  if (previewMode) return previewBookings
  const client = requireClient()
  let query = client.from('bookings').select('*, station:stations(*), profile:profiles(full_name,student_id,phone)').order('service_date').order('departure_time')
  if (!admin && userId) query = query.eq('profile_id', userId)
  const { data, error } = await query
  if (error) throw error
  return (data || []) as Booking[]
}

export async function listStationBookingsAdmin(stationId: string, date?: string, time?: string, status = 'active'): Promise<Booking[]> {
  if (previewMode) {
    return previewBookings.filter((booking) => booking.station_id === stationId && (!date || booking.service_date === date) && (!time || booking.departure_time === time) && (status === 'all' || (status === 'active' ? booking.status === 'confirmed' : booking.status === status)))
  }
  let query = requireClient().from('bookings').select('*, station:stations(*), profile:profiles(full_name,student_id,phone)').eq('station_id', stationId).order('service_date').order('departure_time')
  if (date) query = query.eq('service_date', date)
  if (time) query = query.eq('departure_time', time)
  if (status !== 'all') query = query.eq('status', status === 'active' ? 'confirmed' : status)
  const { data, error } = await query
  if (error) throw error
  return (data || []) as Booking[]
}

export async function listNotifications(userId?: string): Promise<AppNotification[]> {
  if (previewMode) return [{ id: 'notice-1', kind: 'subscription_expiring', title: 'اشتراكك على وشك الانتهاء', body: 'يتبقى 18 يوماً على انتهاء الاشتراك.', is_read: false, created_at: new Date().toISOString() }]
  if (!userId) return []
  const { data, error } = await requireClient().from('notifications').select('*').eq('profile_id', userId).order('created_at', { ascending: false }).limit(50)
  if (error) throw error
  return (data || []) as AppNotification[]
}

export async function createBookingBatch(input: BookingBatchInput, userId?: string): Promise<{ batchId: string; bookings: Booking[] }> {
  if (previewMode) {
    const exists = previewBookings.some((booking) => input.dates.includes(booking.service_date))
    if (exists) throw new Error('BOOKING_DUPLICATE_DATE')
    const batchId = `preview-${Date.now()}`
    const station = previewStations.find((item) => item.id === input.stationId) || previewStations[0]
    const added = input.dates.map((date, index) => ({ id: `${batchId}-${index}`, profile_id: userId || previewProfile.id, station_id: station.id, trip_id: null, service_date: date, departure_time: input.departureTimeId === 'time-1000' ? '10:00' : '09:00', status: 'confirmed' as BookingStatus, booking_batch_id: batchId, station }))
    previewBookings.push(...added)
    return { batchId, bookings: added }
  }
  const { data, error } = await requireClient().rpc('create_booking_batch', { p_station_id: input.stationId, p_departure_time_id: input.departureTimeId, p_dates: input.dates })
  if (error) throw error
  return data as { batchId: string; bookings: Booking[] }
}

export async function createBookingChangeRequest(input: { date: string; stationId: string; departureTimeId: string; reason?: string }, userId?: string): Promise<BookingChangeRequest> {
  if (previewMode) {
    const request: BookingChangeRequest = { id: `request-${Date.now()}`, profile_id: userId || previewProfile.id, requested_date: input.date, station_id: input.stationId, departure_time_id: input.departureTimeId, reason: input.reason || null, status: 'pending', reviewed_at: null, station: previewStations.find((station) => station.id === input.stationId), departure_time: previewTimes.find((time) => time.id === input.departureTimeId) }
    previewRequests.push(request)
    return request
  }
  const { data, error } = await requireClient().rpc('create_booking_change_request', { p_date: input.date, p_station_id: input.stationId, p_departure_time_id: input.departureTimeId, p_reason: input.reason || null })
  if (error) throw error
  return data as BookingChangeRequest
}

export async function listBookingChangeRequestsAdmin(): Promise<BookingChangeRequest[]> {
  if (previewMode) return previewRequests
  const { data, error } = await requireClient().from('booking_change_requests').select('*, profile:profiles(full_name,student_id,phone), station:stations(*), departure_time:departure_times(*)').order('requested_date').order('created_at')
  if (error) throw error
  return (data || []) as BookingChangeRequest[]
}

export async function adminReviewBookingChangeRequest(id: string, status: 'approved' | 'rejected'): Promise<void> {
  if (previewMode) { const request = previewRequests.find((item) => item.id === id); if (request) { request.status = status; request.reviewed_at = new Date().toISOString() }; return }
  const { error } = await requireClient().rpc('admin_review_booking_change_request', { p_request_id: id, p_status: status })
  if (error) throw error
}

export async function cancelBooking(id: string): Promise<void> {
  if (previewMode) { const booking = previewBookings.find((item) => item.id === id); if (booking) booking.status = 'cancelled'; return }
  const { error } = await requireClient().rpc('cancel_booking', { p_booking_id: id })
  if (error) throw error
}

export async function markNotificationRead(id: string): Promise<void> {
  if (previewMode) return
  const { error } = await requireClient().from('notifications').update({ is_read: true }).eq('id', id)
  if (error) throw error
}

export async function updateOwnProfile(userId: string, values: Pick<Profile, 'full_name' | 'phone' | 'default_station_id' | 'university'> & { student_id?: string }): Promise<void> {
  if (previewMode) { Object.assign(previewProfile, values); return }
  const { error } = await requireClient().from('profiles').update(values).eq('id', userId)
  if (error) throw error
}

export async function getDashboardStats(): Promise<DashboardStats> {
  if (previewMode) return { totalStudents: 184, pendingStudents: 12, activeSubscriptions: 156, expiringSubscriptions: 9, expiredSubscriptions: 18, todayBookings: 74, tomorrowBookings: 82, todayPassengers: 68, tripCapacity: 120 }
  const { data, error } = await requireClient().rpc('admin_dashboard_stats')
  if (error) throw error
  return data as DashboardStats
}

export async function adminUpdateProfileStatus(id: string, status: 'approved' | 'rejected' | 'suspended'): Promise<void> {
  if (previewMode) { previewStudents = previewStudents.map((student) => student.id === id ? { ...student, account_status: status, approved_at: status === 'approved' ? new Date().toISOString() : student.approved_at } : student); return }
  const { error } = await requireClient().rpc('admin_update_profile_status', { p_profile_id: id, p_status: status })
  if (error) throw error
}

export async function adminSecurityGuard(action: string): Promise<void> {
  if (previewMode) return
  const { error } = await requireClient().rpc('admin_security_guard', { p_action: action })
  if (error) throw error
}

export async function adminUpdateBookingStatus(id: string, status: BookingStatus): Promise<void> {
  if (previewMode) { const booking = previewBookings.find((item) => item.id === id); if (booking) booking.status = status; return }
  const { error } = await requireClient().rpc('admin_update_booking_status', { p_booking_id: id, p_status: status })
  if (error) throw error
}

export async function adminCreateStation(nameAr: string, nameEn?: string): Promise<void> {
  if (previewMode) { previewStations = [...previewStations, { id: `station-${Date.now()}`, name_ar: nameAr, name_en: nameEn || null, sort_order: previewStations.length + 1, is_active: true }]; return }
  await adminSecurityGuard('station_create')
  const { error } = await requireClient().from('stations').insert({ name_ar: nameAr, name_en: nameEn || null, sort_order: 999, is_active: true })
  if (error) throw error
}

export async function adminCreateDepartureTime(time: string): Promise<void> {
  if (previewMode) { previewTimes = [...previewTimes, { id: `time-${Date.now()}`, time, label: time, sort_order: previewTimes.length + 1, is_active: true }]; return }
  await adminSecurityGuard('departure_time_create')
  const { error } = await requireClient().from('departure_times').insert({ time, label: time, sort_order: 999, is_active: true })
  if (error) throw error
}

export async function listProfilesAdmin(): Promise<Profile[]> {
  if (previewMode) return previewStudents.map((student) => ({ ...student, preferred_weekdays: [...student.preferred_weekdays] }))
  const { data, error } = await requireClient().from('profiles').select('*').eq('role', 'student').order('created_at', { ascending: false })
  if (error) throw error
  return (data || []) as Profile[]
}

export async function listAdminProfiles(): Promise<Profile[]> {
  if (previewMode) return previewAdminProfiles.map((profile) => ({ ...profile }))
  const { data, error } = await requireClient().from('profiles').select('*').in('role', ['admin', 'staff']).order('created_at', { ascending: true })
  if (error) throw error
  return (data || []) as Profile[]
}

export async function adminUpdateAdminStatus(id: string, status: 'active' | 'blocked'): Promise<void> {
  if (previewMode) { previewAdminProfiles = previewAdminProfiles.map((profile) => profile.id === id ? { ...profile, admin_status: status } : profile); return }
  const { error } = await requireClient().rpc('admin_update_admin_status', { p_profile_id: id, p_status: status })
  if (error) throw error
}

export async function listSubscriptionsAdmin(): Promise<Array<Subscription & { profile?: Pick<Profile, 'full_name' | 'student_id' | 'phone'> }>> {
  if (previewMode) return [
    { ...previewSubscription, profile: { full_name: previewProfile.full_name, student_id: previewProfile.student_id, phone: previewProfile.phone } },
    { ...previewSubscription, id: 'sub-2', profile_id: 'student-2', end_date: new Date(Date.now() + 18 * 86400000).toISOString().slice(0, 10), profile: { full_name: 'مريم علي', student_id: 'ST-2026-0134', phone: '01098765432' } },
    { ...previewSubscription, id: 'sub-3', profile_id: 'student-3', end_date: new Date(Date.now() - 3 * 86400000).toISOString().slice(0, 10), status: 'expired', profile: { full_name: 'عمر حسن', student_id: 'ST-2026-0101', phone: '01055554444' } },
  ]
  const { data, error } = await requireClient().from('subscriptions').select('*, profile:profiles(full_name,student_id,phone)').order('end_date')
  if (error) throw error
  return (data || []) as Array<Subscription & { profile?: Pick<Profile, 'full_name' | 'student_id' | 'phone'> }>
}

export async function adminToggleStation(id: string, isActive: boolean): Promise<void> {
  if (previewMode) { previewStations = previewStations.map((station) => station.id === id ? { ...station, is_active: isActive } : station); return }
  await adminSecurityGuard('station_toggle')
  const { error } = await requireClient().from('stations').update({ is_active: isActive }).eq('id', id)
  if (error) throw error
}

export async function adminRenameStation(id: string, nameAr: string): Promise<void> {
  if (previewMode) { previewStations = previewStations.map((station) => station.id === id ? { ...station, name_ar: nameAr } : station); return }
  await adminSecurityGuard('station_rename')
  const { error } = await requireClient().from('stations').update({ name_ar: nameAr }).eq('id', id)
  if (error) throw error
}

export async function adminToggleDepartureTime(id: string, isActive: boolean): Promise<void> {
  if (previewMode) { previewTimes = previewTimes.map((time) => time.id === id ? { ...time, is_active: isActive } : time); return }
  await adminSecurityGuard('departure_time_toggle')
  const { error } = await requireClient().from('departure_times').update({ is_active: isActive }).eq('id', id)
  if (error) throw error
}

export async function adminRenameDepartureTime(id: string, value: string): Promise<void> {
  if (previewMode) { previewTimes = previewTimes.map((time) => time.id === id ? { ...time, time: value, label: value } : time); return }
  await adminSecurityGuard('departure_time_rename')
  const { error } = await requireClient().from('departure_times').update({ time: value, label: value }).eq('id', id)
  if (error) throw error
}

export async function listStationsAdmin(): Promise<Station[]> {
  if (previewMode) return previewStations.map((station) => ({ ...station })).sort((a, b) => a.sort_order - b.sort_order)
  const { data, error } = await requireClient().from('stations').select('id,name_ar,name_en,sort_order,is_active').order('sort_order')
  if (error) throw error
  return (data || []) as Station[]
}

export async function listDepartureTimesAdmin(): Promise<DepartureTime[]> {
  if (previewMode) return previewTimes.map((time) => ({ ...time })).sort((a, b) => a.sort_order - b.sort_order)
  const { data, error } = await requireClient().from('departure_times').select('id,time,label,sort_order,is_active').order('sort_order')
  if (error) throw error
  return (data || []) as DepartureTime[]
}

export async function adminReorderStation(id: string, direction: 'up' | 'down'): Promise<void> {
  const items = await listStationsAdmin()
  const index = items.findIndex((item) => item.id === id)
  const otherIndex = direction === 'up' ? index - 1 : index + 1
  if (index < 0 || otherIndex < 0 || otherIndex >= items.length) return
  const current = items[index]
  const other = items[otherIndex]
  if (previewMode) { const next = previewStations.map((item) => ({ ...item })); const currentIndex = next.findIndex((item) => item.id === current.id); const otherIndex = next.findIndex((item) => item.id === other.id); if (currentIndex >= 0 && otherIndex >= 0) { const order = next[currentIndex].sort_order; next[currentIndex].sort_order = next[otherIndex].sort_order; next[otherIndex].sort_order = order; previewStations = next.sort((a, b) => a.sort_order - b.sort_order) }; return }
  await adminSecurityGuard('station_reorder')
  const client = requireClient()
  const first = await client.from('stations').update({ sort_order: other.sort_order }).eq('id', current.id)
  if (first.error) throw first.error
  const second = await client.from('stations').update({ sort_order: current.sort_order }).eq('id', other.id)
  if (second.error) throw second.error
}

export async function adminReorderDepartureTime(id: string, direction: 'up' | 'down'): Promise<void> {
  const items = await listDepartureTimesAdmin()
  const index = items.findIndex((item) => item.id === id)
  const otherIndex = direction === 'up' ? index - 1 : index + 1
  if (index < 0 || otherIndex < 0 || otherIndex >= items.length) return
  const current = items[index]
  const other = items[otherIndex]
  if (previewMode) { const next = previewTimes.map((item) => ({ ...item })); const currentIndex = next.findIndex((item) => item.id === current.id); const otherIndex = next.findIndex((item) => item.id === other.id); if (currentIndex >= 0 && otherIndex >= 0) { const order = next[currentIndex].sort_order; next[currentIndex].sort_order = next[otherIndex].sort_order; next[otherIndex].sort_order = order; previewTimes = next.sort((a, b) => a.sort_order - b.sort_order) }; return }
  await adminSecurityGuard('departure_time_reorder')
  const client = requireClient()
  const first = await client.from('departure_times').update({ sort_order: other.sort_order }).eq('id', current.id)
  if (first.error) throw first.error
  const second = await client.from('departure_times').update({ sort_order: current.sort_order }).eq('id', other.id)
  if (second.error) throw second.error
}

export async function adminUpdateSubscription(id: string, values: Pick<Subscription, 'start_date' | 'end_date' | 'status'>): Promise<void> {
  if (previewMode) return
  const { error } = await requireClient().rpc('admin_update_subscription', { p_subscription_id: id, p_start_date: values.start_date, p_end_date: values.end_date, p_status: values.status })
  if (error) throw error
}

export async function listSecurityEventsAdmin(): Promise<SecurityEvent[]> {
  if (previewMode) return previewSecurityEvents.map((event) => ({ ...event, metadata: { ...event.metadata } }))
  const { data, error } = await requireClient().from('security_events').select('*, actor:profiles(full_name,student_id,phone)').order('created_at', { ascending: false }).limit(100)
  if (error) throw error
  return (data || []) as SecurityEvent[]
}

export async function adminResolveSecurityEvent(id: string): Promise<void> {
  if (previewMode) { previewSecurityEvents = previewSecurityEvents.map((event) => event.id === id ? { ...event, resolved_at: new Date().toISOString() } : event); return }
  await adminSecurityGuard('security_event_resolve')
  const client = requireClient()
  const { data: userData } = await client.auth.getUser()
  const { error } = await client.from('security_events').update({ resolved_at: new Date().toISOString(), reviewed_by: userData.user?.id || null }).eq('id', id)
  if (error) throw error
}
