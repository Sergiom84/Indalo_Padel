import { clsx } from 'clsx';

const variants = {
  default: 'bg-padel-primary/20 text-padel-accent border-padel-primary/30',
  secondary: 'bg-padel-secondary/20 text-sky-400 border-padel-secondary/30',
  success: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30',
  warning: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
  danger: 'bg-red-500/20 text-red-400 border-red-500/30',
  neutral: 'bg-slate-500/20 text-slate-400 border-slate-500/30',
};

export default function Badge({ children, variant = 'default', className = '' }) {
  return (
    <span
      className={clsx(
        'inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border',
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
