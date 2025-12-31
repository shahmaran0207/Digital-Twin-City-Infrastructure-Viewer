export async function checkBackend() {
  const res = await fetch('/api/health');
  const text = await res.text();
  return text;
}
