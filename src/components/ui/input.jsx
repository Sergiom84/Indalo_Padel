import { clsx } from 'clsx';
import { forwardRef } from 'react';

const Input = forwardRef(function Input({ label, error, className = '', ...props }, ref) {
  return (
    <div className="space-y-1">
      {label && (
        <label className="block text-sm font-medium text-slate-300">{label}</label>
      )}
      <input
        ref={ref}
        className={clsx(
          'w-full px-3 py-2 bg-padel-dark border border-padel-20 rounded-lg text-white placeholder-slate-500',
          'focus:outline-none focus:ring-2 focus:ring-padel-primary/50 focus:border-padel-primary',
          'transition-colors text-sm',
          error && 'border-red-500 focus:ring-red-500/50',
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
    <div className="space-y-1">
      {label && (
        <label className="block text-sm font-medium text-slate-300">{label}</label>
      )}
      <select
        className={clsx(
          'w-full px-3 py-2 bg-padel-dark border border-padel-20 rounded-lg text-white',
          'focus:outline-none focus:ring-2 focus:ring-padel-primary/50 focus:border-padel-primary',
          'transition-colors text-sm',
          error && 'border-red-500',
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
    <div className="space-y-1">
      {label && (
        <label className="block text-sm font-medium text-slate-300">{label}</label>
      )}
      <textarea
        className={clsx(
          'w-full px-3 py-2 bg-padel-dark border border-padel-20 rounded-lg text-white placeholder-slate-500',
          'focus:outline-none focus:ring-2 focus:ring-padel-primary/50 focus:border-padel-primary',
          'transition-colors text-sm resize-none',
          error && 'border-red-500',
          className
        )}
        {...props}
      />
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  );
}
