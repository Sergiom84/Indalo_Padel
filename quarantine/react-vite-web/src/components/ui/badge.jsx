import { clsx } from 'clsx';

const variants = {
  default: 'bg-padel-primary/15 text-padel-primary border-padel-primary/30',
  secondary: 'bg-white/10 text-white border-white/20',
  success: 'bg-green-500/15 text-green-400 border-green-500/30',
  warning: 'bg-amber-500/15 text-amber-400 border-amber-500/30',
  danger: 'bg-red-500/15 text-red-400 border-red-500/30',
  neutral: 'bg-padel-surface2 text-padel-muted border-padel-border',
};

export default function Badge({ children, variant = 'default', className = '' }) {
  return (
    <span
      className={clsx(
        'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold border',
        variants[variant],
        className
      )}
    >
      {children}
    </span>
  );
}

export function LevelBadge({ mainLevel, subLevel }) {
  const colorMap = {
    bajo: 'success',
    medio: 'warning',
    alto: 'danger',
  };

  return (
    <Badge variant={colorMap[mainLevel] || 'default'}>
      {mainLevel} - {subLevel}
    </Badge>
  );
}
