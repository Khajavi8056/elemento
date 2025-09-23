//+------------------------------------------------------------------+//+-------------------------------------------------------------------------------------------------+
//|    راهنمای سیستم امتیازدهی سفارشی (Custom Scoring System Guide) - نسخه 3.2                      |
//|    این راهنما به تفسیر امتیاز نهایی (از ۱۰۰۰) تولید شده توسط تابع OnTester کمک می کند.             |
//|    هدف اصلی، پیدا کردن نتایجی با "توازن" بین تمام معیارهاست، نه فقط بالاترین امتیاز.            |
//+-------------------------------------------------------------------------------------------------+
//
//============================================================================================================================================================
//|  بازه امتیاز (از ۱۰۰۰)   |      سطح      |                                       تفسیر و تحلیل                                       |                                       توصیه                                        |
//|-------------------------|----------------|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
//|  زیر ۵۰۰                |   رد شده 🗑️   |  استراتژی در معیارهای اساسی مثل سودآوری یا تعداد معاملات رد شده و ارزش تحلیل ندارد.       |  حذف کن و به سراغ ترکیب پارامترهای بعدی برو.                                       |
//|-------------------------|----------------|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
//|  ۵۰۰ - ۶۵۰              |    ضعیف 📉    |  ایرادات ساختاری بزرگ دارد. ممکن است سودده باشد، اما با ریسک بالا یا پایداری کم.           |  احتمالاً ارزش وقت گذاشتن ندارد، مگر برای ریشه‌یابی دلیل ضعف آن.                     |
//|-------------------------|----------------|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
//|  ۶۵۰ - ۷۲۰              |  قابل قبول 🥉  |  این کفِ نتایج خوب است. یک استراتژی که کار می‌کند، اما ضعف‌های مشخصی دارد.                |  نقطه شروع برای بررسی. امتیازهای جزئی را تحلیل کن تا بزرگترین ضعفش را پیدا کنی.       |
//|-------------------------|----------------|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
//|  ۷۲۰ - ۷۸۰              |     خوب 👍     |  یک کاندیدای قوی و متعادل. در اکثر معیارها عملکرد خوبی داشته و ضعف‌هایش جزئی هستند.         |  این نتایج را در لیست کوتاه خود قرار بده. به دنبال راه‌هایی برای بهبود ضعف‌ها باش.    |
//|-------------------------|----------------|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
//|  ۷۸۰ - ۸۵۰              |   خیلی خوب 🥈   |  مرز بین خوب و عالی. استراتژی قدرت و توازن بالایی از خود نشان داده و قابل اعتماد است.     |  این‌ها از بهترین نتایج تو خواهند بود. ذخیره و اولویت‌بندی کن برای تحلیل عمیق‌تر.      |
//|-------------------------|----------------|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
//|  ۸۵۰ - ۹۲۰              |     عالی 🥇     |  یک نتیجه استثنایی و بسیار کمیاب. توازن تقریباً بی‌نقصی بین تمام معیارها برقرار است.        |  این نتیجه را از دست نده. تمرکز اصلی تحلیل‌های دستی و تست‌های فوروارد روی اینها باشد. |
//|-------------------------|----------------|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
//|  +۹۲۰                   |  افسانه‌ای 🤯  |  در قلمرو Holy Grail! آنقدر خوب است که باید به آن مشکوک بود. احتمال اورفیتینگ وجود دارد.   |  با شک و تردید اما با دقت بالا بررسی کن. انجام تست‌های فوروارد متعدد الزامی است.     |
//============================================================================================================================================================
//
// --- قانون طلایی: توازن، توازن و باز هم توازن! ---
//
// یادت نره، یک نتیجه با امتیاز 800 که تمام امتیازهای جزئی آن (پایداری، سود، ریسک، کیفیت)
// حول و حوش 0.8 می‌چرخند، هزار بار بهتر از یک نتیجه با امتیاز 850 است که دو امتیاز
// جزئی آن 1.0 و دو امتیاز دیگرش 0.6 است. دنبال یکنواختی و هماهنگی در تمام معیارها باش.
//
//+-------------------------------------------------------------------------------------------------+
//| TestCustomAlgo.mqh                                               |
//| Copyright 2025, HipoAlgoritm - Quantum Division                  |
//| t.me/hipoalgoritm                                                |
//+------------------------------------------------------------------+
//| نسخه 3.0: سیستم امتیازدهی هوشمند بر اساس تعادل، پایداری و کیفیت |
//| به‌روزرسانی: پیاده‌سازی سیستم وزنی، بهبود پایداری ماهانه، تشویق تعداد معاملات بیشتر، پنالتی ملایم برای drawdown |
//| هدف: جلوگیری از اورفیتینگ با تمرکز روی توزیع سود، تعادل ریسک-ریوارد، و کیفیت واقعی استراتژی |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, HipoAlgoritm - Quantum Division"
#property link      "t.me/hipoalgoritm"

//--- گروه: تنظیمات اصلی بهینه‌سازی ---
// پارامترهای ورودی محدود به ضروری‌ترین‌ها برای جلوگیری از نیاز به بهینه‌سازی اضافی
input group "تنظیمات اصلی بهینه‌سازی";
input double InpTargetMonthlyReturn   = 3.0;  // هدف سود ماهانه به درصد (برای بونوس سود بالاتر)
input double InpMaxAcceptableDrawdown = 12.0; // حداکثر دراوداون قابل قبول به درصد (پنالتی ملایم برای کمتر از این، سخت‌تر برای بیشتر)
input double InpMinTradesPerWeek      = 1.5;  // حداقل معاملات در هفته (نسبی، برای پنالتی کم)
input double InpMaxStdDevMonthly      = 2.0;  // حداکثر انحراف معیار سود ماهانه (برای چک نوسان)
input double InpMinWinRate            = 0.65; // حداقل win rate برای تعادل (65%)
input double InpMinRRRatio            = 2.5;  // حداقل risk-reward ratio برای تعادل
input double InpMaxTradeGapMonths     = 1.0;  // حداکثر فاصله بدون معامله به ماه (برای پنالتی خواب سرمایه)

//--- وزن‌های سیستم امتیازدهی (ثابت، اما قابل تنظیم اگر لازم شد) ---
const double WEIGHT_STABILITY     = 0.30; // پایداری (30%)
const double WEIGHT_PROFITABILITY = 0.25; // سودآوری (25%)
const double WEIGHT_RISK_BALANCE  = 0.25; // مدیریت ریسک و تعادل (25%)
const double WEIGHT_TRADE_QUALITY = 0.20; // کیفیت معاملات (20%)

//--- ساختارهای کمکی ---
// ساختار برای نگهداری سودهای ماهانه (برای محاسبه توزیع و پایداری)
struct MonthlyReturn
{
   int    year;       // سال
   int    month;      // ماه
   double start_balance; // بالانس اول ماه
   double profit;     // سود خالص ماه
   double return_pct; // درصد بازگشت ماهانه
};

// ساختار برای نقاط منحنی اکوییتی (برای محاسبات drawdown recovery time و غیره)
struct EquityPoint
{
   datetime time;    // زمان
   double   balance; // بالانس نسبی
};

//--- توابع کمکی ریاضی ---
// محاسبه میانگین آرایه
double ArrayMean(const double &arr[])
{
   int size = ArraySize(arr);
   if(size == 0) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < size; i++) sum += arr[i];
   return sum / size;
}

// محاسبه انحراف معیار آرایه
double ArrayStdDev(const double &arr[])
{
   int size = ArraySize(arr);
   if(size < 2) return 0.0;
   double mean = ArrayMean(arr);
   double sum_sq = 0.0;
   for(int i = 0; i < size; i++) sum_sq += MathPow(arr[i] - mean, 2);
   return MathSqrt(sum_sq / size);
}

// محاسبه حداقل آرایه
double ArrayMin(const double &arr[])
{
   int size = ArraySize(arr);
   if(size == 0) return 0.0;
   double min_val = arr[0];
   for(int i = 1; i < size; i++) if(arr[i] < min_val) min_val = arr[i];
   return min_val;
}

//+------------------------------------------------------------------+
//| محاسبه پایداری ماهانه (Stability Score)                       |
//+------------------------------------------------------------------+
//| هدف: بررسی توزیع سود ماهانه برای جلوگیری از "لاتاری" (سود متمرکز در یک ماه). |
//| محاسبه درصد بازگشت هر ماه، نوسان، تعداد ماه‌های سودده، و حداقل بازگشت.     |
//| امتیاز: normalize بین 0-1، با بونوس برای سود بالاتر از target.              |
//+------------------------------------------------------------------+
double CalculateStabilityScore()
{
   if(!HistorySelect(0, TimeCurrent())) return 0.5; // default اگر داده نباشد

   uint total_deals = HistoryDealsTotal();
   if(total_deals < 5) return 0.5; // پنالتی ملایم برای داده کم

   MonthlyReturn monthly_returns[];
   int months_count = 0;
   double current_balance = 0.0; // بالانس نسبی از صفر شروع می‌شود

   // loop برای ساخت ماه‌ها و محاسبه درصد بازگشت
   for(uint i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         MqlDateTime dt;
         TimeToStruct(deal_time, dt);

         double deal_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                              HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                              HistoryDealGetDouble(ticket, DEAL_SWAP);

         int month_idx = -1;
         for(int j = 0; j < months_count; j++)
         {
            if(monthly_returns[j].year == dt.year && monthly_returns[j].month == dt.mon)
            {
               month_idx = j;
               break;
            }
         }

         if(month_idx == -1) // ماه جدید
         {
            ArrayResize(monthly_returns, months_count + 1);
            monthly_returns[months_count].year = dt.year;
            monthly_returns[months_count].month = dt.mon;
            monthly_returns[months_count].start_balance = current_balance;
            monthly_returns[months_count].profit = deal_profit;
            months_count++;
         }
         else // اضافه به ماه موجود
         {
            monthly_returns[month_idx].profit += deal_profit;
         }

         current_balance += deal_profit; // بروزرسانی بالانس
      }
   }

   if(months_count < 3) return 0.5; // پنالتی ملایم برای ماه‌های کم

   // محاسبه درصد بازگشت هر ماه
   double returns_pct[];
   ArrayResize(returns_pct, months_count);
   int profitable_count = 0;
   for(int i = 0; i < months_count; i++)
   {
      double start_bal = (monthly_returns[i].start_balance > 0) ? monthly_returns[i].start_balance : 1.0; // جلوگیری از تقسیم بر صفر
      monthly_returns[i].return_pct = (monthly_returns[i].profit / start_bal) * 100.0;
      returns_pct[i] = monthly_returns[i].return_pct;
      if(returns_pct[i] > 0) profitable_count++;
   }

   double avg_return = ArrayMean(returns_pct);
   if(avg_return <= 0) return 0.1; // پنالتی برای میانگین منفی

   double std_dev = ArrayStdDev(returns_pct);
   double min_return = ArrayMin(returns_pct);

   // امتیاز پایداری پایه (کمتر نوسان، بالاتر امتیاز)
   double stability = 1.0 / (1.0 + std_dev / InpMaxStdDevMonthly);

   // نسبت ماه‌های سودده
   double profitable_ratio = (double)profitable_count / months_count;

   // پنالتی برای حداقل بازگشت پایین
   double min_penalty = (min_return < -1.0) ? 0.5 : 1.0; // پنالتی اگر زیان ماهانه زیاد

   // بونوس برای سود بالاتر از target
   double bonus = (avg_return > InpTargetMonthlyReturn) ? (avg_return / InpTargetMonthlyReturn) : 1.0;

   // امتیاز نهایی normalize
   double score = stability * profitable_ratio * min_penalty * bonus;
   return MathMin(1.0, MathMax(0.1, score)); // بین 0.1-1
}

//+------------------------------------------------------------------+
//| محاسبه سودآوری (Profitability Score)                           |
//+------------------------------------------------------------------+
//| هدف: امتیاز برای میانگین سود ماهانه با بونوس برای مقادیر بالاتر (مثل 5% > 2%). |
//| ادغام با recovery factor برای کیفیت.                           |
//+------------------------------------------------------------------+
double CalculateProfitabilityScore()
{
   double net_profit = TesterStatistics(STAT_PROFIT);
   if(net_profit <= 0) return 0.1;

   datetime start = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_FIRSTDATE);
   datetime end = TimeCurrent();
   double months = (double)(end - start) / (86400.0 * 30.0); // تقریبی تعداد ماه‌ها
   if(months < 1) months = 1;

   double avg_monthly = (net_profit / TesterStatistics(STAT_INITIAL_DEPOSIT)) / months * 100.0; // درصد تقریبی

   double recovery = TesterStatistics(STAT_RECOVERY_FACTOR);
   if(recovery < 0.3) return 0.1;

   double score = (avg_monthly / InpTargetMonthlyReturn) * MathMin(2.0, recovery); // cap recovery at 2
   return MathMin(1.0, MathMax(0.1, score));
}

//+------------------------------------------------------------------+
//| محاسبه مدیریت ریسک و تعادل (Risk Balance Score)               |
//+------------------------------------------------------------------+
//| هدف: تعادل win rate و RR، پنالتی ملایم برای drawdown.         |
//| پنالتی: برای dd <12% ملایم، dd=5% و dd=12% اختلاف کم، dd>12% سخت‌تر اما نه صفر. |
//| بالای 25% همچنان امتیاز بده تا optimizer کار کنه.             |
//+------------------------------------------------------------------+
double CalculateRiskBalanceScore()
{
   double win_rate = TesterStatistics(STAT_PROFIT_TRADES) / TesterStatistics(STAT_TRADES);
   double avg_win = TesterStatistics(STAT_GROSS_PROFIT) / TesterStatistics(STAT_PROFIT_TRADES);
   double avg_loss = MathAbs(TesterStatistics(STAT_GROSS_LOSS)) / TesterStatistics(STAT_LOSS_TRADES);
   double rr = (avg_loss > 0) ? avg_win / avg_loss : 1.0;

   // امتیاز تعادل: اگر win_rate ~65-70% و rr >=2.5، بالا
   double balance_score = win_rate * rr;
   if(win_rate < InpMinWinRate || rr < InpMinRRRatio) balance_score *= 0.7; // پنالتی برای عدم تعادل
   if(win_rate > 0.9 && rr < 1.0) balance_score *= 0.5; // پنالتی برای اورفیت محتمل

   double max_dd = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);

   // پنالتی drawdown ملایم: exponential decay، اختلاف کم بین 5-12، سخت‌تر برای >12، اما بالای 25 همچنان ~0.2
   double dd_penalty = MathExp(-max_dd / InpMaxAcceptableDrawdown);
   if(max_dd > 25.0) dd_penalty *= 0.5; // سخت‌گیری کم برای خیلی بالا، تا صفر نشه

   double score = balance_score * dd_penalty;
   return MathMin(1.0, MathMax(0.1, score / (InpMinWinRate * InpMinRRRatio))); // normalize
}

//+------------------------------------------------------------------+
//| محاسبه کیفیت معاملات (Trade Quality Score)                     |
//+------------------------------------------------------------------+
//| هدف: تشویق تعداد بیشتر معاملات (1000 > 70)، اما با تعادل.    |
//| پنالتی برای فاصله زیاد (خواب سرمایه)، min 1.5 per week.         |
//+------------------------------------------------------------------+
double CalculateTradeQualityScore()
{
   double total_trades = TesterStatistics(STAT_TRADES);
   if(total_trades < 5) return 0.1;

   datetime start = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_FIRSTDATE);
   datetime end = TimeCurrent();
   double weeks = (double)(end - start) / (86400.0 * 7.0);
   if(weeks < 1) weeks = 1;

   double avg_per_week = total_trades / weeks;

   // پنالتی برای کمتر از min
   double min_penalty = (avg_per_week < InpMinTradesPerWeek) ? (avg_per_week / InpMinTradesPerWeek) : 1.0;

   // بونوس logarithmic برای بیشتر (بدون cap سخت)
   double bonus = MathLog(1.0 + avg_per_week) / MathLog(1.0 + 10.0); // normalize به ~1 برای 10 per week

   // چک حداکثر فاصله (gap)
   if(!HistorySelect(0, TimeCurrent())) return 0.5;
   uint total_deals = HistoryDealsTotal();
   datetime prev_time = 0;
   double max_gap = 0.0;
   for(uint i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         datetime curr_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(prev_time > 0)
         {
            double gap_days = (double)(curr_time - prev_time) / 86400.0;
            if(gap_days > max_gap) max_gap = gap_days;
         }
         prev_time = curr_time;
      }
   }
   double gap_months = max_gap / 30.0;
   double gap_penalty = (gap_months > InpMaxTradeGapMonths) ? 1.0 / (1.0 + (gap_months - InpMaxTradeGapMonths)) : 1.0;

   double score = min_penalty * bonus * gap_penalty;
   return MathMin(1.0, MathMax(0.1, score));
}

//+------------------------------------------------------------------+
//| تابع اصلی OnTester - سیستم امتیازدهی وزنی                    |
//+------------------------------------------------------------------+
//| هدف: محاسبه امتیاز نهایی بر اساس وزن‌ها، با پنالتی ملایم.    |
//| خروجی: امتیاز بزرگ برای optimizer (0-100000).                 |
//+------------------------------------------------------------------+
double OnTester()
{
   // فیلتر اولیه ملایم
   double total_trades = TesterStatistics(STAT_TRADES);
   double net_profit = TesterStatistics(STAT_PROFIT);
   if(total_trades < 5 || net_profit <= 0) return 0.0; // فقط برای خیلی بد، 0

   // محاسبه امتیازها
   double stability_score = CalculateStabilityScore();
   double profitability_score = CalculateProfitabilityScore();
   double risk_balance_score = CalculateRiskBalanceScore();
   double trade_quality_score = CalculateTradeQualityScore();

   // امتیاز وزنی
   double weighted_score = (stability_score * WEIGHT_STABILITY) +
                           (profitability_score * WEIGHT_PROFITABILITY) +
                           (risk_balance_score * WEIGHT_RISK_BALANCE) +
                           (trade_quality_score * WEIGHT_TRADE_QUALITY);

   // مقیاس‌بندی برای optimizer (بزرگ کردن برای تمایز)
   double final_score = weighted_score * 100000.0;
   final_score = MathRound(final_score);

   // دیباگ پرینت
   PrintFormat("امتیاز نهایی: %.0f | پایداری: %.2f, سودآوری: %.2f, ریسک: %.2f, کیفیت: %.2f",
               final_score, stability_score, profitability_score, risk_balance_score, trade_quality_score);

   return final_score;
}
//+------------------------------------------------------------------+

