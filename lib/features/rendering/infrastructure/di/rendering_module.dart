import 'package:injectable/injectable.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/rendering/domain/services/message_rendering_service.dart';
import 'package:wahda_bank/features/rendering/infrastructure/cid_resolver.dart';
import 'package:wahda_bank/features/rendering/infrastructure/html_sanitizer.dart';
import 'package:wahda_bank/features/rendering/infrastructure/message_rendering_service_impl.dart';
import 'package:wahda_bank/features/rendering/infrastructure/preview_cache.dart';

@module
abstract class RenderingModule {
  @LazySingleton()
  HtmlSanitizer provideSanitizer() => HtmlSanitizer();

  @LazySingleton()
  CidResolver provideCidResolver() => CidResolver();

  @LazySingleton()
  PreviewCache providePreviewCache() => PreviewCache();

  @LazySingleton()
  MessageRenderingService provideMessageRenderingService(LocalStore store, HtmlSanitizer sanitizer, CidResolver resolver, PreviewCache cache) =>
      MessageRenderingServiceImpl(store: store, sanitizer: sanitizer, resolver: resolver, cache: cache);
}
