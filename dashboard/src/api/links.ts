import type { Link } from "../types/link";

interface ApiError {
  error: string;
}

const BASE_URL = "http://localhost:4567";

async function apiRequest<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(url, options);
  if (!response.ok) {
    const err: ApiError = await response.json();
    throw new Error(err.error);
  }
  return response.json() as Promise<T>;
}

export function getLinks(): Promise<Link[]> {
  return apiRequest<Link[]>(`${BASE_URL}/links`);
}

export function createLink(url: string): Promise<Link> {
  return apiRequest<Link>(`${BASE_URL}/links`, {
    method: "POST",
    body: new URLSearchParams({ url }),
  });
}

export function updateLink(code: string, url: string): Promise<Link> {
  return apiRequest<Link>(`${BASE_URL}/links/${code}`, {
    method: "PUT",
    body: new URLSearchParams({ url }),
  });
}
