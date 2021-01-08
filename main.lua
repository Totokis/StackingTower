--lose condition
local isLose = false
local score = 100
local lockedScore = 0

-- game parameters
local widthScreen, heightScreen = love.graphics.getDimensions()
local mover = 1
local moveSpeed = 4
local boxWidth = 200
local boxHeight = 100
local perfectPlacePercentage = 0.04
local boxCountToStartCamera = 2

--camera
local shiftedHeight = 0
local destinatedCameraHeight = -boxCountToStartCamera * boxHeight
local currentCameraHeight = 0
local cameraSpeed = 1.5

--klasa Box
Box = {width = 0, height = 0, xPos = 0, yPos = 0}

--cooldown
local cooldownPress = 0
local cooldownValue = 30 --this might be changed

function cooldownResetUpdate()
  if(cooldownPress>0) then
	cooldownPress = cooldownPress - 1
  end
end

-- RESET
function reset()
    score = 100
    playerHeigth = boxHeight 
    playerWidth = boxWidth
    mover = 1
    moveSpeed = 4
    setPlayerBox()
    boxes = {box1}
    isLose = false

    destinatedCameraHeight = -boxCountToStartCamera * boxHeight
    currentCameraHeight = 0
end
--

function Box:create (o)
    o.parent = self
    return o
end

function love.load()
    -- images
    wallImg = love.graphics.newImage("wall_test.png")
    background = love.graphics.newImage("bg_test.png")

	playerWidth = 200
	playerHeigth = 100

	-- pierwszy blok
	box1 = Box:create{width = boxWidth, height = boxHeight, xPos = widthScreen/2 - boxWidth/2, yPos = heightScreen-(boxHeight * 1)}
    boxes = {box1}
    player = {}
    setPlayerBox()
end

-- Camera related
function shiftCameraByBoxSize()
  destinatedCameraHeight = destinatedCameraHeight + boxHeight
end

function updateDrawCamera()
  if(#boxes> boxCountToStartCamera and destinatedCameraHeight>currentCameraHeight) then
  	currentCameraHeight = currentCameraHeight + cameraSpeed
  end
  love.graphics.translate(0, currentCameraHeight)
end

function setPlayerBox()
    local height = boxHeight
    for b in pairs(boxes) do
        height = height + boxes[b].height
    end
    player.x = widthScreen - boxWidth
    player.y = heightScreen - height
end

function love.update(dt)
    cooldownResetUpdate()

    if love.keyboard.isDown("u") then
        shiftCameraByBoxSize()
    end

    if love.keyboard.isDown("r") then
        reset()
    end

    if player.x >= (widthScreen - boxWidth)  then
        mover = -1
    end

    if player.x <= 60 then
        mover = 1
    end

    player.x = player.x + mover*moveSpeed
		
	if (love.mouse.isDown("1") and cooldownPress==0) then
		newBox = Box:create{width = playerWidth, height = playerHeigth, xPos = player.x, yPos = player.y}
		print("move speed", moveSpeed)
		if cutBlock() then 
			table.insert(boxes, newBox)
			playerWidth = newBox.width
			playerHeigth = newBox.height
			setPlayerBox()
	        score = #boxes*boxHeight
            shiftCameraByBoxSize()
            
		else
            if not isLose then
			    lose()
            end
        end
        
		changeDifficultyLevel()
        cooldownPress=cooldownValue
    end
    
end

function changeDifficultyLevel()
    if #boxes > 27 then
        moveSpeed = 9
        cameraSpeed = 3.5
    elseif #boxes > 17 then
        moveSpeed = 7
    elseif #boxes > 13 then
        moveSpeed = 6
        cameraSpeed = 3
    elseif #boxes > 7 then
        moveSpeed = 5
    end
end

function cutBlock()
	local offsetX = boxes[#boxes].xPos - player.x
	-- Nie trafił z lewej lub nie trafił z prawej
	if (player.x + playerWidth) < boxes[#boxes].xPos or player.x > boxes[#boxes].xPos + boxes[#boxes].width then
		return false
    else 
        if offsetX > 0 then
            -- perfect placement
            if offsetX <= boxes[#boxes].width * perfectPlacePercentage then
                newBox.xPos = boxes[#boxes].xPos
                newBox.width = boxes[#boxes].width
                print('perfect throw')
            else
                -- Wystaje z lewej
                newBox.xPos = player.x + offsetX
                newBox.width = newBox.width - offsetX
            end

		-- Wystaje z prawej
        elseif offsetX < 0 then
            -- perfect placement
            if offsetX*-1 <= boxes[#boxes].width * perfectPlacePercentage then
                newBox.xPos = boxes[#boxes].xPos
                newBox.width = boxes[#boxes].width
                print('perfect throw')
            else
                -- wystaje z prawej
                newBox.xPos = player.x
                newBox.width = newBox.width + offsetX
            end

        else
            print('perfect throw')
            newBox.xPos = boxes[#boxes].xPos
            newBox.width = boxes[#boxes].width
		end

		return true
	end

end

function drawBoxes()
    i = 1
    for b in pairs(boxes) do
    	box = boxes[b]
        --love.graphics.rectangle("line", box.xPos, box.yPos, box.width, box.height)
        wallQuadBefore = love.graphics.newQuad(0, 0, box.width, box.height, wallImg:getWidth(), wallImg:getHeight())
        love.graphics.draw(wallImg, wallQuadBefore, box.xPos, box.yPos)
        
        i = i + 1
    end

end

function drawHelpers()
    base = love.graphics.getHeight() 
    local offset = 10
    local leftMargin = 10
    local maxHeight = -#boxes*(boxHeight*offset)

    love.graphics.line(leftMargin,base,leftMargin,maxHeight)--x1, y1, x2, y2

    for i=base,maxHeight,-100 do
        love.graphics.line(leftMargin,i,leftMargin+10,i)
        love.graphics.print(-i+heightScreen,leftMargin+10,i)
    end

   --for debbuging
    for i=base,maxHeight,-base do
        love.graphics.print("Player x: " .. player.x .. " y: " .. player.y .." press r to reset", widthScreen-250, i)
    end
   --for not debugging, priting score
   for i=base,maxHeight,-base do
       love.graphics.print("Score: " .. score, widthScreen-250, i+15)
   end
end

function love.draw()
    --now it draws lose screen if you lose and game screen if you are still playing
    if(isLose==false) then
        updateDrawCamera()
        love.graphics.translate(0, shiftedHeight)
    
        love.graphics.draw(background,0  ,0 - background:getHeight()+heightScreen)
        --love.graphics.rectangle("line", player.x, player.y, playerWidth, playerHeigth)

        -- player template
        -- tworzy obszar od 0,0 (lewy górny) do playerWidth playerHeigth (prawy dolny) (pokrywa cały obraz)
        -- i przesuwający takim obszarem w nim rysuje ile się da textury 
        wallQuad = love.graphics.newQuad(0, 0, playerWidth, playerHeigth, wallImg:getWidth(), wallImg:getHeight())
        love.graphics.draw(wallImg, wallQuad, player.x, player.y)
        drawBoxes()
        -- koordynaty
        drawHelpers()
    else
        loseDraw()
    end
end

function lose()
    lockedScore = score
    isLose = true
end

function loseDraw()
    w = love.graphics.getWidth()
    h = love.graphics.getWidth()
    biggerFont = love.graphics.newFont(50)
    love.graphics.setFont(biggerFont)
    love.graphics.print("You lost", w/2 - 100, h/2-200)
    smallerFont = love.graphics.newFont(15)
    love.graphics.setFont(smallerFont)
    love.graphics.print("Your score: " .. lockedScore, w/2 - 50, h/2-130)
    love.graphics.print("Press R to reset", w/2 - 50, h/2-110)
    
end