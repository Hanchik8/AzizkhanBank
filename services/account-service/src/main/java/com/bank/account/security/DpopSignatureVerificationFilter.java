package com.bank.account.security;

import com.bank.account.service.ClientDeviceService;
import com.bank.account.service.ClientDeviceService.DpopVerificationResult;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.util.StreamUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingRequestWrapper;
import org.springframework.web.servlet.HandlerExceptionResolver;

@Component
public class DpopSignatureVerificationFilter extends OncePerRequestFilter {

    private static final int MAX_CACHED_REQUEST_BODY_SIZE = 1024 * 1024;
    private static final String DEVICE_ID_HEADER = "X-Device-Id";
    private static final String TIMESTAMP_HEADER = "X-Timestamp";
    private static final String SIGNATURE_HEADER = "X-Signature";

    private final ClientDeviceService clientDeviceService;
    private final HandlerExceptionResolver handlerExceptionResolver;

    public DpopSignatureVerificationFilter(
        ClientDeviceService clientDeviceService,
        @Qualifier("handlerExceptionResolver") HandlerExceptionResolver handlerExceptionResolver
    ) {
        this.clientDeviceService = clientDeviceService;
        this.handlerExceptionResolver = handlerExceptionResolver;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String uri = request.getRequestURI();
        return !(uri.equals("/api/v1/transfers") || uri.startsWith("/api/v1/transfers/"));
    }

    @Override
    protected void doFilterInternal(
        HttpServletRequest request,
        HttpServletResponse response,
        FilterChain filterChain
    ) throws ServletException, IOException {
        ContentCachingRequestWrapper cachingRequest = new ContentCachingRequestWrapper(
            request,
            MAX_CACHED_REQUEST_BODY_SIZE
        );
        byte[] requestBody = StreamUtils.copyToByteArray(cachingRequest.getInputStream());
        String rawJsonBody = new String(requestBody, StandardCharsets.UTF_8);

        String deviceId = cachingRequest.getHeader(DEVICE_ID_HEADER);
        String timestamp = cachingRequest.getHeader(TIMESTAMP_HEADER);
        String signature = cachingRequest.getHeader(SIGNATURE_HEADER);

        DpopVerificationResult verificationResult = clientDeviceService.verifyDpopRequest(
            deviceId,
            timestamp,
            signature,
            rawJsonBody
        );

        if (!verificationResult.valid()) {
            DpopSecurityException exception = new DpopSecurityException(
                verificationResult.status(),
                verificationResult.message()
            );
            handlerExceptionResolver.resolveException(cachingRequest, response, null, exception);
            return;
        }

        CachedBodyHttpServletRequest replayableRequest = new CachedBodyHttpServletRequest(cachingRequest, requestBody);
        filterChain.doFilter(replayableRequest, response);
    }

    private static final class CachedBodyHttpServletRequest extends HttpServletRequestWrapper {

        private final byte[] cachedBody;

        private CachedBodyHttpServletRequest(HttpServletRequest request, byte[] cachedBody) {
            super(request);
            this.cachedBody = cachedBody == null ? new byte[0] : cachedBody;
        }

        @Override
        public ServletInputStream getInputStream() {
            return new CachedBodyServletInputStream(cachedBody);
        }

        @Override
        public BufferedReader getReader() {
            return new BufferedReader(new InputStreamReader(getInputStream(), StandardCharsets.UTF_8));
        }

        @Override
        public int getContentLength() {
            return cachedBody.length;
        }

        @Override
        public long getContentLengthLong() {
            return cachedBody.length;
        }
    }

    private static final class CachedBodyServletInputStream extends ServletInputStream {

        private final ByteArrayInputStream bodyInputStream;

        private CachedBodyServletInputStream(byte[] cachedBody) {
            this.bodyInputStream = new ByteArrayInputStream(cachedBody);
        }

        @Override
        public int read() {
            return bodyInputStream.read();
        }

        @Override
        public boolean isFinished() {
            return bodyInputStream.available() == 0;
        }

        @Override
        public boolean isReady() {
            return true;
        }

        @Override
        public void setReadListener(ReadListener readListener) {
            if (readListener == null) {
                return;
            }
            try {
                if (isFinished()) {
                    readListener.onAllDataRead();
                } else {
                    readListener.onDataAvailable();
                }
            } catch (IOException ex) {
                readListener.onError(ex);
            }
        }
    }
}
