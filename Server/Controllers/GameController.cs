using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Data;

namespace Server.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class GameController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public GameController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. 골드 수령 (방치 보상)
        [HttpPost("collect")]
        public async Task<IActionResult> CollectGold([FromBody] GameRequest request)
        {
            var user = await _context.Users.FindAsync(request.UserId);
            if (user == null) return NotFound("유저를 찾을 수 없습니다.");

            // 시간 차이 계산 (초 단위)
            var now = DateTime.UtcNow;
            var timeDiff = (now - user.LastCollectedAt).TotalSeconds;

            if (timeDiff < 1) return BadRequest("너무 빨리 요청했습니다.");

            // 보상 공식: 시간(초) * (장비레벨 * 10)
            long reward = (long)(timeDiff * (user.SwordLevel * 10));

            // 상태 업데이트
            user.Gold += reward;
            user.LastCollectedAt = now;

            await _context.SaveChangesAsync();

            return Ok(new { CurrentGold = user.Gold, Earned = reward });
        }

        // 2. 장비 강화 (트랜잭션 적용 ★중요)
        [HttpPost("upgrade")]
        public async Task<IActionResult> UpgradeSword([FromBody] GameRequest request)
        {
            // 트랜잭션 시작 (원자성 보장)
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                var user = await _context.Users.FindAsync(request.UserId);
                if (user == null) return NotFound();

                // 강화 비용: 현재 레벨 * 1000 골드
                long cost = user.SwordLevel * 1000;

                if (user.Gold < cost) return BadRequest("골드가 부족합니다.");

                // 골드 차감
                user.Gold -= cost;

                // 기본 확률 설정 (예: 1레벨일 때 90%)
                double baseSuccessRate = 90.0;

                // 레벨당 감소치 (예: 레벨당 5%씩 감소)
                double penalty = (user.SwordLevel - 1) * 5.0;

                // 최종 확률 계산 (최소 5%는 보장)
                double finalRate = Math.Max(5.0, baseSuccessRate - penalty);

                // 강화 시도
                var random = new Random();
                bool isSuccess = random.NextDouble() * 100 < finalRate;

                if (isSuccess)
                {
                    user.SwordLevel++;
                }

                // DB 저장
                await _context.SaveChangesAsync();
                
                // 트랜잭션 커밋 (모든 과정이 성공해야 실제 반영)
                await transaction.CommitAsync();

                return Ok(new 
                { 
                    Success = isSuccess, 
                    NewLevel = user.SwordLevel, 
                    CurrentGold = user.Gold,
                    Message = isSuccess ? "강화 성공!" : "강화 실패..."
                });
            }
            catch (Exception)
            {
                // 에러나면 롤백 (골드 차감 취소)
                await transaction.RollbackAsync();
                return StatusCode(500, "서버 에러가 발생했습니다.");
            }
        }
    }

    public class GameRequest
    {
        public int UserId { get; set; }
    }
}
