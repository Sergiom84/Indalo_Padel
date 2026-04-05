import { clsx } from 'clsx';

export function Card({ children, className = '', onClick, ...props }) {
  return (
    <div
      className={clsx(
        'bg-padel-surface rounded-xl border border-padel-20 overflow-hidden',
        onClick && 'cursor-pointer hover:border-padel-40 transition-colors',
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
    <div className={clsx('px-4 py-3 border-b border-padel-20', className)}>
      {children}
    </div>
  );
}

export function CardContent({ children, className = '' }) {
  return (
    <div className={clsx('px-4 py-3', className)}>
      {children}
    </div>
  );
}

export function CardFooter({ children, className = '' }) {
  return (
    <div className={clsx('px-4 py-3 border-t border-padel-20', className)}>
      {children}
    </div>
  );
}
