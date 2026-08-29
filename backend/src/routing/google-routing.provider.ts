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
    const { status, json } = await this.httpPost(
      GOOGLE_ROUTES_URL,
      {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': GOOGLE_FIELD_MASK,
      },
      body,
      routing.timeoutMs,
    );
    if (status >= 500 || status === 429) {
      throw new RoutingProviderError(
        'unavailable',
        'Google routing provider is unavailable',
      );
    }
    if (status >= 400) {
      throw new RoutingProviderError(
        'unavailable',
        'Google routing provider returned an error',
      );
    }
    return parseGoogleComputeRoutesResponse(json, request.points);
  }
}
