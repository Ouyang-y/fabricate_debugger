%{
齐次方程，坐标转换：https://blog.csdn.net/maple_2014/article/details/109300540
图形求解圆心：https://blog.csdn.net/weixin_39750861/article/details/108164852
三维圆弧参数方程：https://blog.sina.com.cn/s/blog_6496e38e0102vi7e.html

三维圆弧，返回三维弧线坐标。
·默认弧方向与x轴平行，可依据参数{'Vbegin',[x,y,z]}设定值。
·默认Pend为终点坐标，若设定参数{'isVend',1}，则为最终弧方向，此时默认为劣弧。
·默认返回增量坐标，若设定参数{'absolute',1}，则返回绝对坐标。
·默认cw为1，设定参数{'cw',0}变相。

输入参输：
    Pend：终点坐标，若isVend=1，则为最终弧方向；
    R：转弯半径；
    num：点数，段数为num-1；
例：
·[x,y,z] = C3D(Pend,R,num)
·[x,y,z] = C3D(Pend,R,num,'isVend',1)
·[x,y,z] = C3D(Pend,R,num,'isVend',1,'cw',0,'absolute',1,'Vbegin',[1,2,3])
输出结果：
    弧线三维坐标。
%}
function [x,y,z,Pend] = C3D(varargin)
if nargin<3,error(message('C3D: at least 3 input var - (Pend,R,num)'));end
if length(varargin{1})~=3,error(message('C3D: Pend need to be 3D'));end
if length(varargin{2})~=1,error(message('C3D: R need to be 1D'));end
if length(varargin{3})~=1,error(message('C3D: num need to be 1D'));end
[Pend,R,num] = varargin{1:3};
isVend=0;cw=1;absolute=0;Vbegin=[1,0,0];
if nargin>3,if ~bitget(nargin,1),error(message('C3D: parameter num error'));end
    for temp = 4:2:nargin
        switch varargin{temp}
            case 'isVend',isVend=varargin{temp+1};
            case 'cw',cw=varargin{temp+1};
            case 'absolute',absolute=varargin{temp+1};
            case 'Vbegin',Vbegin=varargin{temp+1};
            otherwise,error(message('C3D: unrecognized parameter'));
        end
    end
end
Vertical = cross(Vbegin,Pend);	% Vertical为圆弧平面法向量，大小无意义
Vertical = Vertical/norm(Vertical);
Fr1 = cross(Vbegin,Vertical);	% 起点+向量Fr1经过圆心的单位向量
n1 = R*Fr1;  % 参数方程圆径向向量1
Pend(1) = n1(1)+sqrt(R^2-sum((Pend(2:3)+n1(2:3)).^2));
Pend0=Pend/norm(Pend);	% 单位化Pend，仅方向有作用，大小无意义
if isVend
    theta = acos(dot(Vbegin,Pend0));	% 参数方程角度终值，两单位向量夹角值
else
    % Pend代表终点坐标，亦即从起点到终点的向量。
    % 与代表终弧方向时相比，确定弧平面作用相同，不同点在于角度。
    theta = 2*asin(norm(Pend)/2/R);%acos(1-norm(Pend)^2/2/R^2);
end
if cw,Vertical = -Vertical;if ~isVend,Vbegin=-Vbegin;theta=2*pi-theta;end;end
n2 = cross(Vertical,n1); % 参数方程圆径向向量2
t = linspace(0,theta,num);
x = -n1(1)+n1(1)*cos(t)+n2(1)*sin(t);
y = -n1(2)+n1(2)*cos(t)+n2(2)*sin(t);
z = -n1(3)+n1(3)*cos(t)+n2(3)*sin(t);
if absolute,x(1)=[];y(1)=[];z(1)=[];return;end
for temp = length(t):-1:2
    x(temp) = x(temp)-x(temp-1);
    y(temp) = y(temp)-y(temp-1);
    z(temp) = z(temp)-z(temp-1);
end
x(1)=[];y(1)=[];z(1)=[];
end