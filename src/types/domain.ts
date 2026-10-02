export type Role = 'student' | 'admin' | 'staff'
export type AccountStatus = 'pending' | 'approved' | 'rejected' | 'suspended'
export type BookingStatus = 'confirmed' | 'cancelled' | 'boarded' | 'no_show'
export type SubscriptionStatus = 'active' | 'expired' | 'paused' | 'pending'
export type BookingRequestStatus = 'pending' | 'approved' | 'rejected'

export interface Station {
  id: string
  name_ar: string
  name_en: string | null
  sort_order: number
  is_active: boolean
}

export interface DepartureTime {
  id: string
  time: string
  label: string | null
  sort_order: number
  is_active: boolean
}

export interface Profile {
  id: string
  full_name: string
  student_id: string
  email: string
  phone: string
  default_station_id: string | null
  role: Role
  account_status: AccountStatus
  admin_status?: 'active' | 'blocked'
  university: string | null
  approved_at: string | null
  created_at?: string
  preferred_weekdays: number[]
}

export interface BookingHours {
  openTime: string
  closeTime: string
}

export interface Subscription {
  id: string
  profile_id: string
  start_date: string
  end_date: string
  status: SubscriptionStatus
}

export interface Trip {
  id: string
  service_date: string
  departure_time_id: string
  capacity: number
  booked_count: number
  status: 'open' | 'full' | 'closed'
}

export interface Booking {
  id: string
  profile_id: string
  station_id: string
  trip_id: string | null
  service_date: string
  departure_time: string
  status: BookingStatus
  booking_batch_id: string
  station?: Station
  profile?: Pick<Profile, 'full_name' | 'student_id' | 'phone'>
  trip?: Trip
}

export interface AppNotification {
  id: string
  kind: string
  title: string
  body: string
  is_read: boolean
  created_at: string
}

export interface AdminSetting {
  key: string
  value: string
  description: string | null
}

export interface DashboardStats {
  totalStudents: number
  pendingStudents: number
  activeSubscriptions: number
  expiringSubscriptions: number
  expiredSubscriptions: number
  todayBookings: number
  tomorrowBookings: number
  todayPassengers: number
  tripCapacity: number
}

export interface BookingGroup {
  time: string
  station: Station
  students: Array<Pick<Profile, 'id' | 'full_name' | 'student_id' | 'phone'> & { status: BookingStatus }>
}

export interface BookingBatchInput {
  stationId: string
  departureTimeId: string
  dates: string[]
}

export interface BookingChangeRequest {
  id: string
  profile_id: string
  requested_date: string
  station_id: string
  departure_time_id: string
  reason: string | null
  status: BookingRequestStatus
  reviewed_at: string | null
  profile?: Pick<Profile, 'full_name' | 'student_id' | 'phone'>
  station?: Station
  departure_time?: DepartureTime
}

export interface SecurityEvent {
  id: string
  actor_id: string | null
  event_type: string
  severity: 'info' | 'warning' | 'high' | 'critical'
  action: string | null
  reason: string
  metadata: Record<string, unknown>
  blocked_until: string | null
  resolved_at: string | null
  reviewed_by: string | null
  created_at: string
  actor?: Pick<Profile, 'full_name' | 'student_id' | 'phone'>
}
