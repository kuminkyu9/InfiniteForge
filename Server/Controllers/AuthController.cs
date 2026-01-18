using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Data;
using Server.Models;

namespace Server.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public AuthController(ApplicationDbContext context)
        {
            _context = context;
        }

        // POST api/auth/login
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            // 1. 디바이스 ID로 유저 검색
            var user = await _context.Users.FirstOrDefaultAsync(u => u.DeviceId == request.DeviceId);

            // 2. 없으면 회원가입(새로 생성)
            if (user == null)
            {
                user = new User
                {
                    DeviceId = request.DeviceId,
                    Username = $"Player_{Guid.NewGuid().ToString().Substring(0, 8)}", // 랜덤 이름
                    CreatedAt = DateTime.UtcNow,
                    LastCollectedAt = DateTime.UtcNow,
                    SwordLevel = 1,
                    Gold = 0,
                };

                _context.Users.Add(user);
                await _context.SaveChangesAsync();
            }

            // 클라이언트 UI 동기화를 위한 계산
            long currentProfit = user.SwordLevel * 10; 
            long nextCost = user.SwordLevel * 1000;

            // 3. 유저 정보 반환
            // return Ok(user);
            return Ok(new
            {
                id = user.Id,
                Gold = user.Gold,
                SwordLevel = user.SwordLevel,
                ProfitPerSec = currentProfit,   // res.data['profitPerSec'] 
                UpgradeCost = nextCost, // res.data['upgradeCost'] 
                LastCollectedAt = user.LastCollectedAt, 
            });
        }
    }

    // 요청 데이터 구조 (DTO) - 간단해서 파일 분리 안 하고 여기 둠
    public class LoginRequest
    {
        public string DeviceId { get; set; } = string.Empty;
    }
}
