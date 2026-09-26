export default function Modal({ isOpen, title, children, onClose }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[#1f1f1f]/40 px-4 backdrop-blur-[2px]">
      <div className="w-full max-w-2xl rounded-3xl border border-[#f0e9e9] bg-white p-6 shadow-2xl">
        <div className="mb-5 flex items-center justify-between">
          <h3 className="text-xl font-semibold text-[#2d2d2d]">{title}</h3>
          <button type="button" onClick={onClose} className="text-xl text-[#7d7d7d] hover:text-[#333]">×</button>
        </div>
        {children}
      </div>
    </div>
  );
}
