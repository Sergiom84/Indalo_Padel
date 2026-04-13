import { clsx } from 'clsx';

const variants = {
  primary: 'bg-padel-primary text-padel-dark hover:bg-padel-primaryDark font-bold',
  secondary: 'bg-padel-surface2 text-white hover:bg-padel-border border border-padel-border',
  outline: 'border border-padel-primary text-padel-primary hover:bg-padel-primary hover:text-padel-dark font-semibold',
  ghost: 'text-padel-muted hover:text-white hover:bg-padel-surface2',
  danger: 'bg-red-600 hover:bg-red-500 text-white font-semibold',
};

const sizes = {
  sm: 'px-3 py-1.5 text-xs rounded-lg',
  md: 'px-4 py-2.5 text-sm rounded-xl',
  lg: 'px-6 py-3.5 text-base rounded-xl',
};

export default function Button({
  children,
  variant = 'primary',
  size = 'md',
  className = '',
  disabled = false,
  loading = false,
  ...props
}) {
  return (
    <button
      className={clsx(
        'inline-flex items-center justify-center gap-2 font-semibold transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-padel-primary/40 active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed disabled:active:scale-100',
        variants[variant],
        sizes[size],
        className
      )}
      disabled={disabled || loading}
      {...props}
    >
      {loading && (
        <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
      )}
      {children}
    </button>
  );
}
