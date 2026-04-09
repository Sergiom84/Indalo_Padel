import { clsx } from 'clsx';

export function Card({ children, className = '', onClick, ...props }) {
  return (
    <div
      className={clsx(
        'bg-padel-surface rounded-2xl border border-padel-border overflow-hidden',
        onClick && 'cursor-pointer hover:border-padel-primary/40 hover:bg-padel-surface2 transition-all duration-200',
        className
      )}
      onClick={onClick}
      {...props}
    >
      {children}
    </div>
  );
}

export function CardHeader({ children, className = '' }) {
  return (
    <div className={clsx('px-5 py-4 border-b border-padel-border', className)}>
      {children}
    </div>
  );
}

export function CardContent({ children, className = '' }) {
  return (
    <div className={clsx('px-5 py-4', className)}>
      {children}
    </div>
  );
}

export function CardFooter({ children, className = '' }) {
  return (
    <div className={clsx('px-5 py-4 border-t border-padel-border', className)}>
      {children}
    </div>
  );
}
