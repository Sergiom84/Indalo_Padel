import { clsx } from 'clsx';
import { forwardRef } from 'react';

const Input = forwardRef(function Input({ label, error, className = '', ...props }, ref) {
  return (
    <div className="space-y-1.5">
      {label && (
        <label className="block text-xs font-semibold uppercase tracking-wider text-padel-muted">{label}</label>
      )}
      <input
        ref={ref}
        className={clsx(
          'w-full px-4 py-3 bg-padel-surface2 border border-padel-border rounded-xl text-white placeholder-padel-muted',
          'focus:outline-none focus:ring-1 focus:ring-padel-primary/50 focus:border-padel-primary',
          'transition-all duration-200 text-sm',
          error && 'border-red-500/60 focus:ring-red-500/40',
          className
        )}
        {...props}
      />
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  );
});

export default Input;

export function Select({ label, error, children, className = '', ...props }) {
  return (
    <div className="space-y-1.5">
      {label && (
        <label className="block text-xs font-semibold uppercase tracking-wider text-padel-muted">{label}</label>
      )}
      <select
        className={clsx(
          'w-full px-4 py-3 bg-padel-surface2 border border-padel-border rounded-xl text-white',
          'focus:outline-none focus:ring-1 focus:ring-padel-primary/50 focus:border-padel-primary',
          'transition-all duration-200 text-sm',
          error && 'border-red-500/60',
          className
        )}
        {...props}
      >
        {children}
      </select>
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  );
}

export function Textarea({ label, error, className = '', ...props }) {
  return (
    <div className="space-y-1.5">
      {label && (
        <label className="block text-xs font-semibold uppercase tracking-wider text-padel-muted">{label}</label>
      )}
      <textarea
        className={clsx(
          'w-full px-4 py-3 bg-padel-surface2 border border-padel-border rounded-xl text-white placeholder-padel-muted',
          'focus:outline-none focus:ring-1 focus:ring-padel-primary/50 focus:border-padel-primary',
          'transition-all duration-200 text-sm resize-none',
          error && 'border-red-500/60',
          className
        )}
        {...props}
      />
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  );
}
