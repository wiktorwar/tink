/**
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 **************************************************************************
 */

#import "objc/TINKKeysetHandle.h"

#import "objc/TINKAead.h"
#import "objc/TINKKeyTemplate.h"
#import "objc/TINKKeysetReader.h"
#import "objc/aead/TINKAeadInternal.h"
#import "objc/core/TINKKeyTemplate_Internal.h"
#import "objc/core/TINKKeysetReader_Internal.h"
#import "objc/util/TINKErrors.h"
#import "objc/util/TINKStrings.h"

#include "tink/keyset_handle.h"
#include "tink/util/status.h"
#include "proto/tink.pb.h"

@implementation TINKKeysetHandle {
  std::unique_ptr<crypto::tink::KeysetHandle> _ccKeysetHandle;
}

- (instancetype)initWithCCKeysetHandle:(std::unique_ptr<crypto::tink::KeysetHandle>)ccKeysetHandle {
  self = [super init];
  if (self) {
    _ccKeysetHandle = std::move(ccKeysetHandle);
  }
  return self;
}

- (void)dealloc {
  _ccKeysetHandle.reset();
}

- (instancetype)initWithKeysetReader:(TINKKeysetReader *)reader
                              andKey:(id<TINKAead>)aeadKey
                               error:(NSError **)error {
  if (![aeadKey isKindOfClass:[TINKAeadInternal class]]) {
    if (error) {
      *error = TINKStatusToError(crypto::tink::util::Status(
          crypto::tink::util::error::INVALID_ARGUMENT, "Invalid instance of TINKAead."));
    }
    return nil;
  }

  TINKAeadInternal *aead = aeadKey;
  crypto::tink::Aead *ccAead = [aead ccAead];
  if (!ccAead) {
    if (error) {
      *error = TINKStatusToError(crypto::tink::util::Status(
          crypto::tink::util::error::INVALID_ARGUMENT, "Failed to get C++ Aead instance."));
    }
    return nil;
  }

  @synchronized(reader) {
    if (reader.used) {
      // A reader can only be used once.
      if (error) {
        *error = TINKStatusToError(
            crypto::tink::util::Status(crypto::tink::util::error::RESOURCE_EXHAUSTED,
                                       "A KeysetReader can be used only once."));
      }
      return nil;
    }
    reader.used = YES;
  }
  auto st = crypto::tink::KeysetHandle::Read(reader.ccReader, *ccAead);
  if (!st.ok()) {
    if (error) {
      *error = TINKStatusToError(st.status());
      return nil;
    }
  }

  return [self initWithCCKeysetHandle:std::move(st.ValueOrDie())];
}

- (instancetype)initWithKeyTemplate:(TINKKeyTemplate *)keyTemplate error:(NSError **)error {
  auto st = crypto::tink::KeysetHandle::GenerateNew(*(keyTemplate.ccKeyTemplate));
  if (!st.ok()) {
    if (error) {
      *error = TINKStatusToError(st.status());
    }
    return nil;
  }

  return [self initWithCCKeysetHandle:std::move(st.ValueOrDie())];
}

- (crypto::tink::KeysetHandle *)ccKeysetHandle {
  return _ccKeysetHandle.get();
}

- (void)setCcKeysetHandle:(std::unique_ptr<crypto::tink::KeysetHandle>)handle {
  _ccKeysetHandle = std::move(handle);
}

@end
