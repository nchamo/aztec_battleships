// SVG Icons for Battleships game

interface IconProps {
  className?: string;
  size?: number;
}

// Ship bow (front) - pointed end
export function ShipBow({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="shipGradient" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#6B7280" />
          <stop offset="50%" stopColor="#4B5563" />
          <stop offset="100%" stopColor="#374151" />
        </linearGradient>
      </defs>
      <path
        d="M16 4 L28 16 L28 28 L4 28 L4 16 Z"
        fill="url(#shipGradient)"
        stroke="#1F2937"
        strokeWidth="2"
      />
      <circle cx="16" cy="18" r="3" fill="#374151" stroke="#1F2937" strokeWidth="1" />
    </svg>
  );
}

// Ship middle segment
export function ShipMiddle({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="shipMiddleGrad" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#6B7280" />
          <stop offset="50%" stopColor="#4B5563" />
          <stop offset="100%" stopColor="#374151" />
        </linearGradient>
      </defs>
      <rect
        x="4"
        y="4"
        width="24"
        height="24"
        fill="url(#shipMiddleGrad)"
        stroke="#1F2937"
        strokeWidth="2"
      />
      <line x1="4" y1="16" x2="28" y2="16" stroke="#374151" strokeWidth="2" />
    </svg>
  );
}

// Ship stern (back) - flat end
export function ShipStern({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="shipSternGrad" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#6B7280" />
          <stop offset="50%" stopColor="#4B5563" />
          <stop offset="100%" stopColor="#374151" />
        </linearGradient>
      </defs>
      <path
        d="M4 4 L28 4 L28 28 L4 28 L10 16 Z"
        fill="url(#shipSternGrad)"
        stroke="#1F2937"
        strokeWidth="2"
      />
      <rect x="20" y="12" width="4" height="8" fill="#374151" stroke="#1F2937" strokeWidth="1" />
    </svg>
  );
}

// Hit icon - bold red X
export function ExplosionIcon({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Red X mark */}
      <line x1="8" y1="8" x2="24" y2="24" stroke="#EF4444" strokeWidth="4" strokeLinecap="round" />
      <line x1="24" y1="8" x2="8" y2="24" stroke="#EF4444" strokeWidth="4" strokeLinecap="round" />
    </svg>
  );
}

// Miss icon - white dot/circle
export function SplashIcon({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* White circle for miss */}
      <circle cx="16" cy="16" r="6" fill="white" opacity="0.9" />
    </svg>
  );
}

// Radar/pending icon - pulsing radar
export function RadarIcon({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="radarGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#22C55E" />
          <stop offset="100%" stopColor="#16A34A" />
        </linearGradient>
      </defs>
      {/* Radar circles */}
      <circle cx="16" cy="16" r="12" fill="none" stroke="#22C55E" strokeWidth="1" opacity="0.3" />
      <circle cx="16" cy="16" r="8" fill="none" stroke="#22C55E" strokeWidth="1" opacity="0.5" />
      <circle cx="16" cy="16" r="4" fill="none" stroke="#22C55E" strokeWidth="1" opacity="0.7" />
      {/* Radar sweep */}
      <path
        d="M16 16 L16 4 A12 12 0 0 1 28 16 Z"
        fill="url(#radarGrad)"
        opacity="0.6"
      />
      {/* Center dot */}
      <circle cx="16" cy="16" r="2" fill="#22C55E" />
    </svg>
  );
}

// Crosshair/targeting icon
export function CrosshairIcon({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Outer circle */}
      <circle cx="16" cy="16" r="12" fill="none" stroke="#EF4444" strokeWidth="2" opacity="0.8" />
      {/* Inner circle */}
      <circle cx="16" cy="16" r="6" fill="none" stroke="#EF4444" strokeWidth="1.5" opacity="0.6" />
      {/* Crosshairs */}
      <line x1="16" y1="2" x2="16" y2="10" stroke="#EF4444" strokeWidth="2" />
      <line x1="16" y1="22" x2="16" y2="30" stroke="#EF4444" strokeWidth="2" />
      <line x1="2" y1="16" x2="10" y2="16" stroke="#EF4444" strokeWidth="2" />
      <line x1="22" y1="16" x2="30" y2="16" stroke="#EF4444" strokeWidth="2" />
      {/* Center dot */}
      <circle cx="16" cy="16" r="2" fill="#EF4444" />
    </svg>
  );
}

// Shield icon for "Your Fleet" header
export function ShieldIcon({ className = '', size = 24 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      className={className}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M12 2L4 6V12C4 16.4183 7.58172 20 12 20C16.4183 20 20 16.4183 20 12V6L12 2Z"
        fill="#3B82F6"
        stroke="#1D4ED8"
        strokeWidth="2"
      />
      <path
        d="M9 12L11 14L15 10"
        stroke="white"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

// Target icon for "Enemy Waters" header
export function TargetIcon({ className = '', size = 24 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      className={className}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <circle cx="12" cy="12" r="9" stroke="#EF4444" strokeWidth="2" />
      <circle cx="12" cy="12" r="5" stroke="#EF4444" strokeWidth="2" />
      <circle cx="12" cy="12" r="1" fill="#EF4444" />
      <line x1="12" y1="1" x2="12" y2="5" stroke="#EF4444" strokeWidth="2" />
      <line x1="12" y1="19" x2="12" y2="23" stroke="#EF4444" strokeWidth="2" />
      <line x1="1" y1="12" x2="5" y2="12" stroke="#EF4444" strokeWidth="2" />
      <line x1="19" y1="12" x2="23" y2="12" stroke="#EF4444" strokeWidth="2" />
    </svg>
  );
}

// Water/ocean cell background
export function WaterCell({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="waterGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#1E3A5F" />
          <stop offset="100%" stopColor="#0F172A" />
        </linearGradient>
      </defs>
      <rect width="32" height="32" fill="url(#waterGrad)" />
      {/* Wave lines */}
      <path
        d="M0 12 Q8 8 16 12 Q24 16 32 12"
        fill="none"
        stroke="#2563EB"
        strokeWidth="1"
        opacity="0.3"
      />
      <path
        d="M0 20 Q8 16 16 20 Q24 24 32 20"
        fill="none"
        stroke="#2563EB"
        strokeWidth="1"
        opacity="0.2"
      />
    </svg>
  );
}

// Simple ship cell (for when we don't need bow/middle/stern distinction)
export function ShipCell({ className = '', size = 32 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      className={className}
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <linearGradient id="simpleShipGrad" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#6B7280" />
          <stop offset="50%" stopColor="#4B5563" />
          <stop offset="100%" stopColor="#374151" />
        </linearGradient>
      </defs>
      <rect
        x="2"
        y="2"
        width="28"
        height="28"
        rx="4"
        fill="url(#simpleShipGrad)"
        stroke="#1F2937"
        strokeWidth="2"
      />
      <circle cx="16" cy="16" r="4" fill="#374151" stroke="#1F2937" strokeWidth="1" />
      <circle cx="16" cy="16" r="2" fill="#4B5563" />
    </svg>
  );
}
