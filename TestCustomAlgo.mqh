//+------------------------------------------------------------------+
//| TestCustomAlgo.mqh                                               |
//| Copyright 2025, HipoAlgoritm - Quantum Division                  |
//| t.me/hipoalgoritm                                                |
//+------------------------------------------------------------------+
//| نسخه 2.3: گسترش بازه امتیازها برای تمایز بیشتر و اعداد بزرگ‌تر |
//| به‌روزرسانی: تغییر فیلتر اولیه به بازگشت 0، افزایش مقیاس، ملایم‌سازی لگاریتم |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, HipoAlgoritm - Quantum Division"
#property link      "t.me/hipoalgoritm"
//+------------------------------------------------------------------+

//--- گروه: تنظیمات بهینه‌سازی سفارشی ---
// این گروه شامل پارامترهای ورودی برای تنظیمات اصلی بهینه‌سازی است.
input group "تنظیمات اصلی بهینه‌سازی";
input int    InpMinTradesPerYear      = 10;  // حداقل تعداد معاملات قابل قبول در یک سال [اصلاح‌شده: از 20 به 10 برای کمتر سخت‌گیر بودن]
input double InpMaxAcceptableDrawdown = 30.0; // حداکثر دراوداون قابل قبول به درصد

input group "فیلتر کیفیت معامله (مقابله با اورفیتینگ)";
input double InpMinimumProfitToCostRatio = 2.0; // حداقل نسبت سود خالص هر معامله به هزینه آن
input double InpEstimatedCostPerTrade    = 1.5; // هزینه تخمینی هر معامله (اسپرد+کمیسیون) به پیپ

input group "تحلیل مدت زمان معامله";
input double InpDurationPenaltyThreshold = 1.5; // آستانه جریمه برای نسبت میانگین زمان زیان‌ده به سودده (اگر بیشتر باشد، جریمه)

//--- ساختارهای کمکی ---
// ساختار برای نگهداری نقاط منحنی اکوییتی (برای محاسبات آماری مانند R-Squared و Sortino Ratio)
struct EquityPoint
{
   datetime time;    // زمان نقطه اکوییتی
   double   balance; // موجودی در آن زمان
};

// ساختار برای نگهداری سودهای ماهانه (برای محاسبه پایداری سود ماهانه)
struct MonthlyProfit
{
   int    year;  // سال
   int    month; // ماه
   double profit; // سود خالص ماه
};

//--- توابع کمکی ریاضی برای محاسبات آماری ---
// محاسبه میانگین یک آرایه (میانگین حسابی عناصر آرایه)
double ArrayMean(const double &arr[])
{
   int size = ArraySize(arr);
   if(size == 0) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < size; i++)
   {
      sum += arr[i];
   }
   return sum / size;
}

// محاسبه انحراف معیار یک آرایه (برای اندازه‌گیری نوسان)
double ArrayStdDev(const double &arr[])
{
   int size = ArraySize(arr);
   if(size < 2) return 0.0;

   double mean = ArrayMean(arr);
   double sum_sq_diff = 0.0;
   for(int i = 0; i < size; i++)
   {
      sum_sq_diff += MathPow(arr[i] - mean, 2);
   }
   return MathSqrt(sum_sq_diff / size);
}

//+------------------------------------------------------------------+
//| [جدید] محاسبه امتیاز پایداری سود ماهانه (Monthly Profit Stability)|
//+------------------------------------------------------------------+
//| هدف: این تابع به شدت استراتژی‌هایی را تشویق می‌کند که سودهای |
//| ماهانه پایدار و قابل اتکایی دارند (مانند یک حقوق ماهانه). |
//| و استراتژی‌های "لاتاری" که با یک معامله بزرگ شانس، کل سود |
//| را کسب می‌کنند، به شدت جریمه می‌کند.                         |
//| ورودی: هیچ (از تاریخچه معاملات استفاده می‌کند)                |
//| خروجی: امتیاز پایداری بین 0 تا 1                              |
//+------------------------------------------------------------------+
double CalculateMonthlyProfitStats()
{
   if(!HistorySelect(0, TimeCurrent())) return 0.0;

   uint total_deals = HistoryDealsTotal();
   if(total_deals < 3) return 0.1; // حداقل 0.1 برای جلوگیری از صفر شدن

   MonthlyProfit monthly_profits[]; // آرایه دینامیک برای نگهداری سودهای ماهانه
   int months_count = 0;

   // حلقه در تمام معاملات برای دسته‌بندی سودها بر اساس ماه
   for(uint i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         MqlDateTime dt;
         TimeToStruct(deal_time, dt);

         int month_idx = -1;
         // جستجو برای یافتن ماه موجود
         for(int j = 0; j < months_count; j++)
         {
            if(monthly_profits[j].year == dt.year && monthly_profits[j].month == dt.mon)
            {
               month_idx = j;
               break;
            }
         }

         double deal_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                              HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                              HistoryDealGetDouble(ticket, DEAL_SWAP);

         if(month_idx == -1) // اگر ماه جدید بود
         {
            ArrayResize(monthly_profits, months_count + 1);
            monthly_profits[months_count].year = dt.year;
            monthly_profits[months_count].month = dt.mon;
            monthly_profits[months_count].profit = deal_profit;
            months_count++;
         }
         else // اگر ماه قبلاً وجود داشت
         {
            monthly_profits[month_idx].profit += deal_profit;
         }
      }
   }

   if(months_count <= 1) return 1.0; // اگر فقط یک ماه فعالیت داشته، پایداری کامل است

   // استخراج سودهای ماهانه در یک آرایه double برای محاسبات آماری
   double profits_array[];
   ArrayResize(profits_array, months_count);
   double total_monthly_profit = 0.0;
   for(int i = 0; i < months_count; i++)
   {
      profits_array[i] = monthly_profits[i].profit;
      total_monthly_profit += profits_array[i];
   }

   // اگر میانگین سود ماهانه منفی باشد، امتیاز کم اما غیرصفر
   if(total_monthly_profit / months_count <= 0) return 0.1;

   // محاسبه انحراف معیار سودهای ماهانه
   double std_dev_monthly_profits = ArrayStdDev(profits_array);

   // فرمول امتیاز: هرچه انحراف معیار (نوسان) کمتر باشد، امتیاز به 1 نزدیک‌تر است
   return 1.0 / (1.0 + std_dev_monthly_profits / MathMax(1.0, AccountInfoDouble(ACCOUNT_BALANCE) * 0.01));
}

//+------------------------------------------------------------------+
//| [جدید] محاسبه فاکتور کیفیت معامله (Trade Quality Factor)      |
//+------------------------------------------------------------------+
//| هدف: این تابع یک مکانیسم قدرتمند ضد اورفیتینگ است. با فیلتر کردن |
//| معاملاتی که سودشان به قدری ناچیز است که توسط هزینه‌های |
//| واقعی (اسپرد، کمیسیون) از بین می‌رود، از انتخاب استراتژی‌های |
//| غیرواقعی جلوگیری می‌کند.                                      |
//| ورودی: هیچ (از تاریخچه معاملات استفاده می‌کند)                |
//| خروجی: فاکتور کیفیت بین 0 تا 1                                |
//+------------------------------------------------------------------+
double CalculateTradeQualityFactor()
{
   if(!HistorySelect(0, TimeCurrent())) return 0.1;

   uint total_deals = HistoryDealsTotal();
   if(total_deals == 0) return 0.1;

   int high_quality_trades = 0;
   int closed_trades_count = 0;

   double point_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double cost_per_pip = InpEstimatedCostPerTrade * point_value;

   for(uint i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         closed_trades_count++;
         double net_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                             HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                             HistoryDealGetDouble(ticket, DEAL_SWAP);

         double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
         // هزینه تخمینی معامله بر اساس حجم
         double estimated_cost = cost_per_pip * volume / point_value;

         // یک معامله باکیفیت است اگر سود خالص آن حداقل N برابر هزینه تخمینی باشد
         if(net_profit > (estimated_cost * InpMinimumProfitToCostRatio))
         {
            high_quality_trades++;
         }
      }
   }

   if(closed_trades_count == 0) return 0.1;

   // فاکتور کیفیت، درصد معاملات باکیفیت است
   return (double)high_quality_trades / closed_trades_count;
}

//+------------------------------------------------------------------+
//| [جدید] محاسبه نسبت سود به زیان (Profit/Loss Ratio)             |
//+------------------------------------------------------------------+
//| هدف: این معیار، میانگین اندازه سودها را با میانگین اندازه ضررها |
//| مقایسه می‌کند. یک نسبت بالا (مثلاً > 1.5) نشان می‌دهد که |
//| استراتژی دارای یک مزیت (Edge) سالم در مدیریت ریسک به ریوارد |
//| است.                                                            |
//| ورودی: هیچ (از آمار تستر استفاده می‌کند)                      |
//| خروجی: نسبت سود به زیان (عدد مثبت)                             |
//+------------------------------------------------------------------+
double CalculateProfitLossRatio()
{
   double gross_profit = TesterStatistics(STAT_GROSS_PROFIT);
   double profit_trades_count = TesterStatistics(STAT_PROFIT_TRADES);
   double gross_loss = MathAbs(TesterStatistics(STAT_GROSS_LOSS));
   double loss_trades_count = TesterStatistics(STAT_LOSS_TRADES);

   if(profit_trades_count == 0 || loss_trades_count == 0 || gross_loss == 0)
   {
      return 5.0; // مقدار متعادل برای شرایط خاص
   }

   double avg_win = gross_profit / profit_trades_count;
   double avg_loss = gross_loss / loss_trades_count;

   return avg_win / avg_loss;
}

//+------------------------------------------------------------------+
//| [جدید و پیشرفته] محاسبه نسبت سورتینو (Sortino Ratio)          |
//+------------------------------------------------------------------+
//| هدف: سورتینو یک نسخه برتر از نسبت شارپ است. این معیار فقط نوسانات|
//| منفی (ریسک نزولی) را جریمه می‌کند و به نوسانات مثبت (رشدهای |
//| سریع) پاداش می‌دهد. این معیار، ریسک را از دیدگاه یک سرمایه‌گذار|
//| واقعی‌تر می‌سنجد.                                               |
//| نکته: محاسبه این معیار نیازمند پردازش منحنی اکوییتی است و کمی |
//| سنگین‌تر از معیارهای استاندارد تستر است، اما ارزش تحلیلی |
//| بسیار بالایی دارد.                                              |
//| ورودی: آرایه منحنی اکوییتی                                    |
//| خروجی: نسبت سورتینو (عدد مثبت، بالاتر بهتر)                    |
//+------------------------------------------------------------------+
double CalculateSortinoRatio(const EquityPoint &equity_curve[])
{
   int points = ArraySize(equity_curve);
   if(points < 3) return 0.1;

   // 1. محاسبه بازده‌های دوره‌ای از روی منحنی اکوییتی
   double returns[];
   ArrayResize(returns, points - 1);
   for(int i = 1; i < points; i++)
   {
      if(equity_curve[i-1].balance > 0)
      {
         // استفاده از بازده لگاریتمی برای پایداری ریاضی
         returns[i-1] = MathLog(equity_curve[i].balance / equity_curve[i-1].balance);
      }
      else
      {
         returns[i-1] = 0.0;
      }
   }

   // 2. محاسبه میانگین بازده‌ها
   double average_return = ArrayMean(returns);
   if (average_return <= 0) return 0.1;

   // 3. جداسازی بازده‌های منفی برای محاسبه انحراف معیار نزولی
   double downside_returns[];
   int downside_count = 0;
   ArrayResize(downside_returns, ArraySize(returns));
   for(int i = 0; i < ArraySize(returns); i++)
   {
      if(returns[i] < 0)
      {
         downside_returns[downside_count] = returns[i];
         downside_count++;
      }
   }
   if(downside_count < 2) return 5.0;

   ArrayResize(downside_returns, downside_count);

   // 4. محاسبه انحراف معیار نزولی (Downside Deviation)
   double downside_deviation = ArrayStdDev(downside_returns);

   if(downside_deviation == 0) return 5.0;

   // 5. محاسبه نسبت سورتینو
   return average_return / downside_deviation;
}

////+------------------------------------------------------------------+
//| [اصلاح نهایی] محاسبه معیارهای پیشرفته مبتنی بر منحنی اکوییتی     |
//+------------------------------------------------------------------+
//| نسخه جدید به TesterStatistics وابسته نیست و فقط بر اساس تاریخچه |
//| انتخاب شده توسط HistorySelect کار می‌کند. این باعث می‌شود برای   |
//| تحلیل بازه‌های زمانی خاص (مثل نیمه‌های بک‌تست) دقیق باشد.     |
//+------------------------------------------------------------------+
void ProcessEquityCurve(double &r_squared, double &sortino_ratio)
{
   // مقادیر اولیه
   r_squared = 0.0;
   sortino_ratio = 0.0;

   // [اصلاح شده] HistorySelect قبلاً در تابع والد (مثلاً CalculateMetricsForPeriod) فراخوانی شده است.
   uint total_deals = HistoryDealsTotal();
   if(total_deals < 3) return;

   // --- 1. ساخت آرایه منحنی اکوییتی نسبی (Relative Equity Curve) ---
   EquityPoint equity_curve[];
   ArrayResize(equity_curve, (int)total_deals + 1);

   // [اصلاح شده] به جای استفاده از بالانس اولیه، از یک منحنی نسبی که از صفر شروع می‌شود استفاده می‌کنیم.
   // این برای محاسبه سورتینو و R-Squared کاملاً کافی و صحیح است.
   equity_curve[0].time = (total_deals > 0) ? (datetime)HistoryDealGetInteger(0, DEAL_TIME) - 1 : 0;
   equity_curve[0].balance = 0.0; // شروع از صفر

   int equity_points = 1;
   for(uint i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         equity_curve[equity_points].time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         equity_curve[equity_points].balance = equity_curve[equity_points-1].balance +
                                               HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                                               HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                                               HistoryDealGetDouble(ticket, DEAL_SWAP);
         equity_points++;
      }
   }
   ArrayResize(equity_curve, equity_points);
   if(equity_points < 2) return;

   // --- 2. محاسبه R-Squared (خطی بودن منحنی) ---
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0;
   for(int i = 0; i < equity_points; i++)
   {
      double x = i + 1.0;
      double y = equity_curve[i].balance;
      sum_x += x; sum_y += y; sum_xy += x * y; sum_x2 += x*x; sum_y2 += y*y;
   }
   double n = equity_points;
   double den_part1 = (n * sum_x2) - (sum_x * sum_x);
   double den_part2 = (n * sum_y2) - (sum_y * sum_y);
   if(den_part1 > 0 && den_part2 > 0)
   {
      double r = ((n * sum_xy) - (sum_x * sum_y)) / MathSqrt(den_part1 * den_part2);
      r_squared = r * r;
   }

   // --- 3. محاسبه نسبت سورتینو با استفاده از منحنی اکوییتی ساخته شده ---
   sortino_ratio = CalculateSortinoRatio(equity_curve);
}


//+------------------------------------------------------------------+
//| [بدون تغییر] محاسبه ضریب مجازات دراوداون با منحنی کسینوسی   |
//+------------------------------------------------------------------+
//| هدف: محاسبه یک ضریب جریمه برای دراوداون بر اساس یک منحنی کسینوسی.|
//| هرچه دراوداون بیشتر، جریمه بیشتر (نزدیک به صفر).             |
//| ورودی: درصد حداکثر دراوداون                                    |
//| خروجی: ضریب جریمه بین 0 تا 1                                  |
//+------------------------------------------------------------------+
double CalculateDrawdownPenalty(double max_drawdown_percent)
{
   double penalty_factor = 0.0;
   if (max_drawdown_percent < InpMaxAcceptableDrawdown && InpMaxAcceptableDrawdown > 0)
   {
      // تبدیل درصد دراوداون به یک زاویه بین 0 تا 90 درجه (π/2 رادیان)
      double angle = (max_drawdown_percent / InpMaxAcceptableDrawdown) * (M_PI / 2.0);
      // ضریب مجازات، کسینوس آن زاویه است. هرچه زاویه (دراوداون) بیشتر، کسینوس (امتیاز) کمتر
      penalty_factor = MathCos(angle);
   }
   return penalty_factor;
}

//+------------------------------------------------------------------+
//| [اصلاح شده] محاسبه فاکتور تحلیل مدت زمان معامله (Trade Duration Factor) |
//+------------------------------------------------------------------+
//| هدف: بررسی میانگین مدت زمان نگهداری معاملات سودده و زیان‌ده.   |
//| اگر میانگین زمان زیان‌ده بیشتر از آستانه‌ای از میانگین سودده باشد، جریمه اعمال می‌شود. |
//| این کار از استراتژی‌هایی که ضررها را نگه می‌دارند جلوگیری می‌کند. |
//| ورودی: هیچ (از تاریخچه معاملات استفاده می‌کند)                |
//| خروجی: فاکتور بین 0 تا 1 (1 یعنی بدون جریمه)                  |
//+------------------------------------------------------------------+
double CalculateTradeDurationFactor()
{
   if(!HistorySelect(0, TimeCurrent())) return 0.1;

   uint total_deals = HistoryDealsTotal();
   if(total_deals < 3) return 1.0; // اگر تعداد معاملات کم است، جریمه‌ای نیست

   double sum_profit_duration = 0.0;
   int profit_count = 0;
   double sum_loss_duration = 0.0;
   int loss_count = 0;

   for(uint i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         datetime exit_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         ulong position_id = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         datetime entry_time = 0;

         // [اصلاح شده] جستجو برای یافتن زمان ورود معامله متناظر
         for(uint j = 0; j < i; j++)
         {
            ulong entry_ticket = HistoryDealGetTicket(j);
            if(HistoryDealGetInteger(entry_ticket, DEAL_POSITION_ID) == position_id &&
               HistoryDealGetInteger(entry_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
               entry_time = (datetime)HistoryDealGetInteger(entry_ticket, DEAL_TIME);
               break; // معامله ورودی پیدا شد
            }
         }

         if(entry_time == 0) continue; // اگر زمان ورود پیدا نشد، از این معامله بگذر

         double duration = (double)(exit_time - entry_time); // مدت زمان به ثانیه

         double net_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                             HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                             HistoryDealGetDouble(ticket, DEAL_SWAP);

         if(net_profit > 0)
         {
            sum_profit_duration += duration;
            profit_count++;
         }
         else if(net_profit < 0)
         {
            sum_loss_duration += duration;
            loss_count++;
         }
      }
   }

   if(profit_count == 0 || loss_count == 0 || sum_profit_duration == 0) return 1.0; // اگر یکی از گروه‌ها خالی باشد، بدون جریمه

   double avg_profit_duration = sum_profit_duration / profit_count;
   double avg_loss_duration = sum_loss_duration / loss_count;

   // جلوگیری از تقسیم بر صفر اگر میانگین سود صفر باشد
   if(avg_profit_duration <= 0) return 1.0;

   double duration_ratio = avg_loss_duration / avg_profit_duration;

   if(duration_ratio <= InpDurationPenaltyThreshold) return 1.0;

   // جریمه معکوس بر اساس نسبت بیش از آستانه
   return 1.0 / (1.0 + (duration_ratio - InpDurationPenaltyThreshold));
}

//+------------------------------------------------------------------+
//| [جدید] تابع کمکی برای محاسبه آمار پیشرفته در یک بازه زمانی خاص |
//+------------------------------------------------------------------+
void CalculateMetricsForPeriod(datetime from_time, datetime to_time, double &out_score)
{
   out_score = 0;
   if(!HistorySelect(from_time, to_time)) return;

   uint total_deals = HistoryDealsTotal();
   if(total_deals < 3) return;

   // --- محاسبه دستی سود خالص و دراوداون برای بازه ---
   double net_profit = 0;
   double max_drawdown = 0;
   double peak_balance = 0;
   double current_balance = 0;

   for(uint i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         double deal_profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                              HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                              HistoryDealGetDouble(ticket, DEAL_SWAP);
         net_profit += deal_profit;
         current_balance += deal_profit;

         if(current_balance > peak_balance)
         {
            peak_balance = current_balance;
         }
         double drawdown = peak_balance - current_balance;
         if(drawdown > max_drawdown)
         {
            max_drawdown = drawdown;
         }
      }
   }

   if(net_profit <= 0) return;
   if(max_drawdown == 0) max_drawdown = net_profit; // برای جلوگیری از تقسیم بر صفر

   double recovery_factor = net_profit / max_drawdown;

   // --- ساخت منحنی اکوییتی نسبی و محاسبه سورتینو و R^2 ---
   double r_squared = 0.0, sortino_ratio = 0.0;
   ProcessEquityCurve(r_squared, sortino_ratio); // ProcessEquityCurve باید با HistorySelect کار کند

   // امتیاز نهایی برای این بازه
   out_score = net_profit * recovery_factor * MathMax(0.1, sortino_ratio) * MathMax(0.1, r_squared);
}

//+------------------------------------------------------------------+
//| [اصلاح شده] محاسبه ضریب ثبات عملکرد (Performance Stability Factor) |
//+------------------------------------------------------------------+
//| هدف: تقسیم دوره بک‌تست به دو نیمه و مقایسه عملکرد دو نیمه.    |
//| این کار پایداری استراتژی در شرایط مختلف بازار را می‌سنجد.       |
//+------------------------------------------------------------------+
double CalculatePerformanceStabilityFactor()
{
   datetime test_start = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_FIRSTDATE);
   datetime test_end = TimeCurrent();
   if(test_start >= test_end || (test_end - test_start) < 86400 * 60) return 0.1; // حداقل 2 ماه داده لازم است

   datetime midpoint = test_start + (test_end - test_start) / 2;

   // محاسبه آمار برای نیمه اول
   double score_h1 = 0;
   CalculateMetricsForPeriod(test_start, midpoint, score_h1);

   // محاسبه آمار برای نیمه دوم
   double score_h2 = 0;
   CalculateMetricsForPeriod(midpoint, test_end, score_h2);

   // [اصلاح شده] ProcessEquityCurve و سایر توابع باید بعد از هر CalculateMetricsForPeriod
   // با داده‌های کل دوره ریست شوند. برای این کار، HistorySelect را به کل دوره برمی‌گردانیم.
   HistorySelect(0, TimeCurrent());

   if(score_h1 <= 0 || score_h2 <= 0) return 0.1; // اگر هر نیمه زیان‌ده باشد، امتیاز پایین

   // محاسبه تفاوت نسبی
   double diff = MathAbs(score_h1 - score_h2) / (score_h1 + score_h2);
   
   // ضریب ثبات: هرچه تفاوت کمتر، ضریب نزدیک‌تر به 1
   return 1.0 - diff;
}

//+------------------------------------------------------------------+
//| تابع اصلی رویداد تستر (OnTester) - نسخه 2.3 با گسترش بازه امتیاز |
//| معماری جدید با فرمول امتیازدهی یکپارچه و چندعاملی             |
//+------------------------------------------------------------------+
//| هدف: محاسبه امتیاز نهایی برای بهینه‌سازی استراتژی بر اساس معیارهای |
//| پیشرفته مانند پایداری، کیفیت معاملات، سورتینو و غیره.        |
//| ورودی: هیچ                                                       |
//| خروجی: امتیاز نهایی (عدد صحیح مثبت، بالاتر بهتر)              |
//+------------------------------------------------------------------+
double OnTester()
{
   // --- مرحله 1: دریافت آمارهای استاندارد و اولیه ---
   double total_trades = TesterStatistics(STAT_TRADES);
   double net_profit = TesterStatistics(STAT_PROFIT);
   double profit_factor = TesterStatistics(STAT_PROFIT_FACTOR);
   double recovery_factor = TesterStatistics(STAT_RECOVERY_FACTOR);
   double profit_trades = TesterStatistics(STAT_PROFIT_TRADES);
   double win_rate_factor = (total_trades > 0) ? (profit_trades / total_trades) : 0.1;
   double max_dd_percent = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);

   // --- مرحله 2: فیلترهای اولیه برای رد کردن پاس‌های ضعیف ---
   datetime test_start = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_FIRSTDATE);
   datetime test_end = TimeCurrent();
   double duration_days = (test_end > test_start) ? double(test_end - test_start) / 86400.0 : 1.0;
   double required_min_trades = MathFloor((duration_days / 365.0) * InpMinTradesPerYear);
   if(required_min_trades < 5) required_min_trades = 5;

   if(total_trades < required_min_trades ||
      profit_factor < 1.0 ||
      net_profit <= 0 ||
      recovery_factor < 0.3)
   {
      Print("رد شده در فیلتر اولیه: معاملات=", total_trades, ", PF=", profit_factor, ", سود=", net_profit, ", RF=", recovery_factor);
      return 0.0; // [اصلاح‌شده: بازگشت 0 به جای 1 برای رد کامل پاس‌های بد و گسترش بازه]
   }

   // --- مرحله 3: محاسبه معیارهای پیشرفته و سفارشی ---
   double r_squared = 0.0, sortino_ratio = 0.0;
   ProcessEquityCurve(r_squared, sortino_ratio);

   double monthly_stability_score = CalculateMonthlyProfitStats();
   double trade_quality_factor = CalculateTradeQualityFactor();
   double profit_loss_ratio = CalculateProfitLossRatio();
   double drawdown_penalty = CalculateDrawdownPenalty(max_dd_percent);
   double trade_duration_factor = CalculateTradeDurationFactor();
   double performance_stability_factor = CalculatePerformanceStabilityFactor();

   // --- مرحله 4: فرمول نهایی امتیازدهی یکپارچه (Grand Unified Scoring Formula) ---
   // بخش 1: امتیاز پایه (سود و تعداد معاملات با تعدیل ملایم‌تر برای رشد سریع‌تر) [اصلاح‌شده: از MathSqrt به جای MathLog برای اعداد بزرگ‌تر]
   double base_score = MathSqrt(1.0 + MathMax(0, net_profit)) * MathSqrt(1.0 + total_trades);

   // بخش 2: فاکتورهای اصلی عملکرد و ریسک
   double core_performance_factor = recovery_factor * MathMax(0.1, sortino_ratio) * profit_loss_ratio * MathMax(0.1, r_squared);

   // بخش 3: فاکتورهای کیفیت، پایداری و واقع‌گرایی (با افزودن فاکتورهای جدید)
   double quality_stability_factor = MathMax(0.1, monthly_stability_score) * MathMax(0.1, trade_quality_factor) * MathMax(0.1, win_rate_factor) * MathMax(0.1, trade_duration_factor) * MathMax(0.1, performance_stability_factor);
   
   // محاسبه امتیاز نهایی و مقیاس‌بندی [اصلاح‌شده: ضریب 10000 برای گسترش بازه و اعداد بزرگ‌تر]
   double final_score = base_score * core_performance_factor * quality_stability_factor * MathMax(0.1, drawdown_penalty) * 10000.0;
   final_score = MathRound(final_score); // تبدیل به عدد صحیح

   // --- مرحله 5: چاپ نتیجه برای دیباگ و تحلیل ---
   PrintFormat("نتیجه: سود خالص=%.2f, معاملات=%d -> امتیاز نهایی: %.0f", net_profit, (int)total_trades, final_score);
   PrintFormat("   -> جزئیات: PF=%.2f, RF=%.2f, Sortino=%.2f, R²=%.3f, P/L=%.2f", profit_factor, recovery_factor, sortino_ratio, r_squared, profit_loss_ratio);
   PrintFormat("   -> کیفیت: پایداری ماهانه=%.3f, کیفیت معاملات=%.2f, WinRate=%.2f, DurationFactor=%.2f, StabilityFactor=%.2f", monthly_stability_score, trade_quality_factor, win_rate_factor, trade_duration_factor, performance_stability_factor);
   PrintFormat("   -> ریسک: دراوداون=%.2f%%, جریمه=%.3f", max_dd_percent, drawdown_penalty);
   
   return final_score;
}
//+------------------------------------------------------------------+
