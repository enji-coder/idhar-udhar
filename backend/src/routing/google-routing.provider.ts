import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppLogger } from '../common/logger/app-logger';
import { AppConfig } from '../config/configuration';
import {
  GOOGLE_FIELD_MASK,
  GOOGLE_ROUTES_URL,
  buildGoogleComputeRoutesBody,
  parseGoogleComputeRoutesResponse,
} from './google-routes.parse';
import {
  RoutingProvider,
  RoutingProviderError,
  RoutingRequest,
  RoutingResult,
} from './routing-provider';

export const GOOGLE_ROUTES_MAX_ATTEMPTS = 2;

function isTransientHttpStatus(status: number): boolean {
  return status === 429 || status >= 500;
}

export type RoutingHttpPost = (
  url: string,
  headers: Record<string, string>,
  body: unknown,
  timeoutMs: number,
) => Promise<{ status: number; json: unknown }>;

export async function defaultRoutingHttpPost(
  url: string,
  headers: Record<string, string>,
  body: unknown,
  timeoutMs: number,
): Promise<{ status: number; json: unknown }> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await response.text();
    let json: unknown = null;
    if (text.length > 0) {
      try {
        json = JSON.parse(text) as unknown;
      } catch {
        throw new RoutingProviderError(
          'invalid_response',
          'Google routing response is not JSON',
        );
      }
    }
    return { status: response.status, json };
  } catch (err) {
    if (err instanceof RoutingProviderError) {
      throw err;
    }
    throw new RoutingProviderError(
      'unavailable',
      'Google routing provider is unavailable',
    );
  } finally {
    clearTimeout(timer);
  }
}

@Injectable()
export class GoogleRoutingProvider implements RoutingProvider {
  readonly provider = 'google' as const;
  private httpPost: RoutingHttpPost = defaultRoutingHttpPost;

  constructor(
    private readonly configService: ConfigService,
    private readonly logger: AppLogger,
  ) {}

  useHttpPost(httpPost: RoutingHttpPost): void {
    this.httpPost = httpPost;
  }

  async route(request: RoutingRequest): Promise<RoutingResult> {
    const routing = this.configService.getOrThrow<AppConfig['routing']>('routing');
    const apiKey = routing.googleApiKey;
    if (!apiKey) {
      throw new RoutingProviderError(
        'unavailable',
        'GOOGLE_MAPS_API_KEY is not configured',
      );
    }
    const body = buildGoogleComputeRoutesBody(request.points);
    this.logger.info('routing_provider_request', {
      provider: 'google',
      waypoint_count: Math.max(0, request.points.length - 2),
      stop_count: request.points.length,
    });
    const headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': GOOGLE_FIELD_MASK,
    };

    let lastUnavailable: RoutingProviderError | null = null;
    for (let attempt = 1; attempt <= GOOGLE_ROUTES_MAX_ATTEMPTS; attempt += 1) {
      let status: number;
      let json: unknown;
      try {
        const response = await this.httpPost(
          GOOGLE_ROUTES_URL,
          headers,
          body,
          routing.timeoutMs,
        );
        status = response.status;
        json = response.json;
      } catch (err) {
        if (err instanceof RoutingProviderError && err.kind === 'invalid_response') {
          throw err;
        }
        lastUnavailable =
          err instanceof RoutingProviderError && err.kind === 'unavailable'
            ? err
            : new RoutingProviderError(
                'unavailable',
                'Google routing provider is unavailable',
              );
        if (attempt < GOOGLE_ROUTES_MAX_ATTEMPTS) {
          continue;
        }
        throw lastUnavailable;
      }

      if (isTransientHttpStatus(status)) {
        lastUnavailable = new RoutingProviderError(
          'unavailable',
          'Google routing provider is unavailable',
        );
        if (attempt < GOOGLE_ROUTES_MAX_ATTEMPTS) {
          continue;
        }
        throw lastUnavailable;
      }
      if (status >= 400) {
        throw new RoutingProviderError(
          'unavailable',
          'Google routing provider returned an error',
        );
      }
      return parseGoogleComputeRoutesResponse(json, request.points);
    }

    throw (
      lastUnavailable ??
      new RoutingProviderError(
        'unavailable',
        'Google routing provider is unavailable',
      )
    );
  }
}
