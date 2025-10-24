# C# (.NET Core) コーディング規約

## 基本方針

- **Clean Architecture**
- **Dependency Injection必須**
- **async/await推奨**

---

## プロジェクト構成（Clean Architecture）

```
MyApp/
├── MyApp.API/           # Web API
├── MyApp.Application/   # Use cases
├── MyApp.Domain/        # Domain models
└── MyApp.Infrastructure/ # DB, External APIs
```

---

## コーディング規約

### 命名規則

```csharp
// ✅ Good: PascalCase
public class UserService
{
    public async Task<User> GetUserAsync(int userId) { }
}

// ✅ Good: private field は _camelCase
private readonly IUserRepository _userRepository;
```

### Dependency Injection

```csharp
// ✅ Good
public class UserService
{
    private readonly IUserRepository _userRepository;

    public UserService(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }
}

// Startup.cs
services.AddScoped<IUserRepository, UserRepository>();
services.AddScoped<IUserService, UserService>();
```

### 非同期処理

```csharp
// ✅ Good
public async Task<User> GetUserAsync(int userId)
{
    return await _userRepository.FindByIdAsync(userId);
}

// ❌ Bad: 同期メソッド（I/O処理なのに）
public User GetUser(int userId)
{
    return _userRepository.FindById(userId);
}
```

### エラーハンドリング

```csharp
// ✅ Good
public class UserNotFoundException : Exception
{
    public UserNotFoundException(int userId)
        : base($"User with ID {userId} not found") { }
}

public async Task<User> GetUserAsync(int userId)
{
    var user = await _userRepository.FindByIdAsync(userId);
    if (user == null)
    {
        throw new UserNotFoundException(userId);
    }
    return user;
}
```

---

## テスト

- **フレームワーク**: xUnit
- **モック**: Moq
- **カバレッジ**: coverlet

```csharp
public class UserServiceTests
{
    [Fact]
    public async Task GetUser_WhenUserExists_ReturnsUser()
    {
        // Arrange
        var mockRepo = new Mock<IUserRepository>();
        mockRepo.Setup(r => r.FindByIdAsync(1))
                .ReturnsAsync(new User { Id = 1 });

        // Act
        var service = new UserService(mockRepo.Object);
        var user = await service.GetUserAsync(1);

        // Assert
        Assert.Equal(1, user.Id);
    }
}
```

---

**参照**: `.claude/docs/10_facilitation/2.4_実装フェーズ/2.4.5_言語別コーディング規約適用/2.4.5.3_C#規約適用/`
