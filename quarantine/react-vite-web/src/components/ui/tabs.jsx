import { useState } from 'react';
import { clsx } from 'clsx';

export function Tabs({ tabs, defaultTab, children }) {
  const [active, setActive] = useState(defaultTab || tabs[0]?.value);

  return (
    <div>
      <div className="flex gap-1 bg-padel-dark rounded-lg p-1 mb-4">
        {tabs.map(tab => (
          <button
            key={tab.value}
            onClick={() => setActive(tab.value)}
            className={clsx(
              'flex-1 px-3 py-2 rounded-md text-sm font-medium transition-colors',
              active === tab.value
                ? 'bg-padel-primary text-white'
                : 'text-slate-400 hover:text-white'
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>
      {typeof children === 'function' ? children(active) : children}
    </div>
  );
}
