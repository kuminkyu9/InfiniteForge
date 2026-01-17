using System.ComponentModel.DataAnnotations;

namespace Server.Models
{
    public class User
    {
        [Key]
        public int Id { get; set; } // PK (Auto Increment)

        [Required]
        public string DeviceId { get; set; } = string.Empty; // 로그인용 디바이스 ID

        public string Username { get; set; } = string.Empty;

        public long Gold { get; set; } = 0; // 보유 골드

        public int SwordLevel { get; set; } = 1; // 검 강화 레벨

        public DateTime LastCollectedAt { get; set; } = DateTime.UtcNow; // 마지막 골드 수령 시간

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
