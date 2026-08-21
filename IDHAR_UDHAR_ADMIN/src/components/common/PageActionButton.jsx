import { Plus } from 'lucide-react';
import Button from './Button';

export default function PageActionButton({ label, onClick }) {
  return (
    <Button icon={Plus} onClick={onClick} className="shrink-0 whitespace-nowrap px-5">
      {label}
    </Button>
  );
}
