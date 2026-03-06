# Azizkhan Bank

Микросервисное банковское приложение с мобильным клиентом на Flutter.

## Архитектура

```
Flutter App ──► Gateway (8080) ──┬──► auth-service    (OTP, JWT, device binding)
                                 ├──► account-service  (счета, переводы, ledger)
                                 └──► user-service     (управление пользователями)

Kafka ──► notification-service (SMS)
      ──► fraud-service        (Kafka Streams, детекция мошенничества)
```

## Технологии

| Компонент | Технология |
|-----------|------------|
| Mobile/Web | Flutter (Dart) |
| Backend | Java 21, Spring Boot 3 |
| API Gateway | Spring Cloud Gateway |
| База данных | PostgreSQL 16 |
| Кэш | Redis 7 |
| Очереди | Apache Kafka |
| Миграции | Liquibase |
| Контейнеризация | Docker, Docker Compose |
| Оркестрация | Kubernetes, Helm |
| GitOps | ArgoCD |
| IaC | Terraform (GCP) |
| CI/CD | GitHub Actions |

## Быстрый старт

### Требования
- Docker & Docker Compose
- Java 21+ (для локальной разработки)
- Flutter SDK 3.11+ (для мобильного приложения)

### Запуск

```bash
# Сгенерировать JWT secret
export JWT_SECRET=$(openssl rand -base64 48)

# Запустить все сервисы
docker compose up -d

# Проверить статус
docker compose ps
```

### Flutter-приложение

```bash
cd azizkhan_bank_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<host>:8080
```

## Сервисы

| Сервис | Порт | Описание |
|--------|------|----------|
| gateway-service | 8080 | API Gateway, rate limiting, маршрутизация |
| auth-service | internal | OTP, JWT-токены, привязка устройств |
| account-service | internal | Счета, переводы, комиссии, ledger |
| user-service | internal | Управление пользователями |
| notification-service | internal | Отправка SMS (Kafka consumer) |
| fraud-service | internal | Детекция мошенничества (Kafka Streams) |

## Безопасность

- JWT + DPoP подпись устройства
- OTP с лимитом попыток и constant-time сравнением
- Replay-защита через nonce в Redis
- Distributed locking через Redisson
- Non-root Docker containers
- Rate limiting на gateway

## API

### Аутентификация
- `POST /api/v1/auth/send-otp` — отправка OTP
- `POST /api/v1/auth/verify-otp` — проверка OTP
- `POST /api/v1/auth/device/bind` — привязка устройства
- `POST /api/v1/auth/refresh` — обновление токенов

### Счета
- `GET /api/v1/accounts` — список счетов
- `GET /api/v1/accounts/{id}/history?page=0&size=50` — история операций

### Переводы
- `POST /api/v1/transfers` — перевод средств (DPoP-подпись обязательна)
